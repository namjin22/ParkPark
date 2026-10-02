--!strict

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Server-authoritative saves. Every player has a profile under the key `Player_<UserId>` holding their coins;
-- the player who hosts the server (the first to join, then the next earliest if they leave) also stores a copy
-- of the park (open or not, entrance, each attraction's unlock/repair/upgrade levels, janitors, guests served),
-- and that copy is what rebuilds the park at the next server start. Nothing here trusts the client: it only
-- reads server-side state.
--
-- Safety rules: loads and saves retry with backoff; a per-key session lock (job id + time) keeps two servers
-- from writing the same profile; and if a profile could not be loaded (or its lock could not be taken), it is
-- never saved this session, so a failed load cannot overwrite good data with a fresh start. Where the API
-- is unavailable (Studio without "Enable Studio Access to API Services") saves go to memory and are lost when
-- the server closes; the ServerStorage StringValue `DebugSaveSeed` (JSON of a saved profile) seeds that mode
-- for tests.
local PersistenceService = {}

export type SavedState = {
	Park: {
		EntranceCleared: boolean,
		ParkOpen: boolean,
		GuestsBoarded: number,
		GoalsClaimed: number,
		QuestIndex: number,
		Mechanics: number,
		PlotsBought: number,
		[string]: any,
	},
	Rides: { [string]: { IsUnlocked: boolean, IsRepaired: boolean, IncomeLevel: number, StaffLevel: number } },
	Janitors: number,
}

type Profile = {
	player: Player,
	key: string,
	status: string, -- "loading" | "ok" | "failed"
	coins: number?,
	speed: number,
	park: SavedState?,
	lastCoins: number,
	dirty: boolean,
	urgent: boolean,
	lastSave: number,
	saving: boolean,
	released: boolean,
}

type Backend = {
	name: string,
	update: (string, (any) -> any) -> (boolean, any),
	remove: (string) -> (),
}

local STORE_NAME = "ParkParkSave"
local STORE_SCOPE = "v1"
local SAVE_VERSION = 1
local LOCK_SECONDS = 180
local LOAD_ATTEMPTS = 4
local SAVE_ATTEMPTS = 4
local TICK_SECONDS = 5
local URGENT_GAP = 6
local NORMAL_GAP = 30
local REFRESH_GAP = 60
local CLOSE_WAIT = 25
local MAX_COINS = 1e9
local JOB_ID = if game.JobId ~= "" then game.JobId else "studio"

local profiles: { [Player]: Profile } = {}
local activeBackend: Backend? = nil
local hostPlayer: Player? = nil
local collectPark: (() -> SavedState)? = nil
local memory: { [string]: any } = {}
local seed: any = nil

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = deepCopy(inner)
	end
	return copy
end

local function ensureBackend(): Backend
	if activeBackend then
		return activeBackend
	end

	local realStore = DataStoreService:GetDataStore(STORE_NAME, STORE_SCOPE)
	local probeOk, probeError = pcall(function()
		return realStore:GetAsync("__probe")
	end)
	if probeOk or not string.find(tostring(probeError), "Studio access", 1, true) then
		local datastore: Backend = {
			name = "datastore",
			update = function(key: string, transform: (any) -> any): (boolean, any)
				return pcall(function()
					return realStore:UpdateAsync(key, transform)
				end)
			end,
			remove = function(key: string)
				pcall(function()
					realStore:RemoveAsync(key)
				end)
			end,
		}
		activeBackend = datastore
		return datastore
	end

	warn("[ParkPark] DataStore is not available here; progress is kept in memory and will not persist")
	local seedValue = ServerStorage:FindFirstChild("DebugSaveSeed")
	if seedValue and seedValue:IsA("StringValue") then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(seedValue.Value)
		end)
		if ok then
			seed = decoded
			print("[ParkPark] Using DebugSaveSeed as the saved profile in memory mode")
		end
	end
	local inMemory: Backend = {
		name = "memory",
		update = function(key: string, transform: (any) -> any): (boolean, any)
			local old = memory[key]
			if old == nil and seed ~= nil then
				old = deepCopy(seed)
			end
			local ok, result = pcall(transform, deepCopy(old))
			if not ok then
				return false, result
			end
			if result ~= nil then
				memory[key] = deepCopy(result)
			end
			return true, result
		end,
		remove = function(key: string)
			memory[key] = nil
		end,
	}
	activeBackend = inMemory
	return inMemory
end

local function attempt(run: () -> (boolean, any), tries: number): (boolean, any)
	local ok, result = false, nil
	for index = 1, tries do
		ok, result = run()
		if ok then
			return true, result
		end
		if index < tries then
			task.wait(math.min(2 ^ (index - 1), 8))
		end
	end
	return false, result
end

local function asNumber(value: any, low: number, high: number, fallback: number): number
	if type(value) ~= "number" or value ~= value then
		return fallback
	end
	return math.floor(math.clamp(value, low, high))
end

-- Turns stored data into something safe to apply: only known fields, right types, levels within the config.
local function sanitizePark(raw: any): SavedState?
	if type(raw) ~= "table" then
		return nil
	end

	local parkRaw = if type(raw.Park) == "table" then raw.Park else {}
	local state: SavedState = {
		Park = {
			EntranceCleared = parkRaw.EntranceCleared == true,
			ParkOpen = parkRaw.ParkOpen == true,
			GuestsBoarded = asNumber(parkRaw.GuestsBoarded, 0, 1e9, 0),
			GoalsClaimed = asNumber(parkRaw.GoalsClaimed, 0, #GameConfig.Goals, 0),
			QuestIndex = asNumber(parkRaw.QuestIndex, 0, #GameConfig.Quests, 0),
			Mechanics = asNumber(parkRaw.Mechanics, 0, #GameConfig.MechanicCosts, 0),
			PlotsBought = asNumber(parkRaw.PlotsBought, 0, #GameConfig.DecorPlotKinds * 2, 0),
		},
		Rides = {},
		Janitors = asNumber(raw.Janitors, 0, #GameConfig.JanitorCosts, 0),
	}
	for zone in GameConfig.ZoneCosts do
		state.Park["Zone_" .. zone] = parkRaw["Zone_" .. zone] == true
	end
	local ridesRaw = if type(raw.Rides) == "table" then raw.Rides else {}
	for key, config in GameConfig.Rides do
		local rideRaw = ridesRaw[key]
		if type(rideRaw) == "table" then
			local repaired = rideRaw.IsRepaired == true
			state.Rides[key] = {
				IsUnlocked = repaired or rideRaw.IsUnlocked == true,
				IsRepaired = repaired,
				IncomeLevel = asNumber(rideRaw.IncomeLevel, 0, #config.IncomeCosts, 0),
				StaffLevel = asNumber(rideRaw.StaffLevel, 0, #config.StaffCosts, 0),
			}
		end
	end
	-- The park cannot be open before the entrance is clean and the carousel is repaired.
	local carousel = state.Rides.Carousel
	if state.Park.ParkOpen and not (state.Park.EntranceCleared and carousel and carousel.IsRepaired) then
		state.Park.ParkOpen = false
	end
	return state
end

local function currentCoins(player: Player): number?
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	return if coins and coins:IsA("IntValue") then coins.Value else nil
end

local function loadProfile(player: Player): Profile
	local existing = profiles[player]
	if existing then
		while existing.status == "loading" do
			task.wait(0.1)
		end
		return existing
	end

	local profile: Profile = {
		player = player,
		key = "Player_" .. tostring(player.UserId),
		status = "loading",
		coins = nil,
		speed = 0,
		park = nil,
		lastCoins = 0,
		dirty = false,
		urgent = false,
		lastSave = os.clock(),
		saving = false,
		released = false,
	}
	profiles[player] = profile

	local store = ensureBackend()
	local locked = false
	local loaded = false
	local data: any = nil
	for index = 1, LOAD_ATTEMPTS do
		locked = false
		local ok, result = store.update(profile.key, function(old: any): any
			local lock = if type(old) == "table" then old.Lock else nil
			if type(lock) == "table" and lock.JobId ~= JOB_ID and os.time() - (lock.Time or 0) < LOCK_SECONDS then
				locked = true
				return nil
			end
			local fresh = if type(old) == "table" then old else {}
			fresh.Version = SAVE_VERSION
			fresh.Lock = { JobId = JOB_ID, Time = os.time() }
			return fresh
		end)
		if ok and not locked and type(result) == "table" then
			loaded = true
			data = result
			break
		end
		if locked then
			warn(string.format("[ParkPark] %s's save is in use by another server; retrying", player.Name))
			task.wait(5)
		elseif not ok then
			warn(string.format("[ParkPark] Could not load %s's save (%s); retrying", player.Name, tostring(result)))
			task.wait(math.min(2 ^ (index - 1), 8))
		end
	end

	if not loaded then
		profile.status = "failed"
		warn(
			string.format(
				"[ParkPark] %s's progress could not be loaded, so it will not be saved this session",
				player.Name
			)
		)
		return profile
	end

	if player.Parent ~= Players then
		-- They left while the load was retrying: hand the lock back so another server can load the save at once.
		store.update(profile.key, function(old: any): any
			local lock = if type(old) == "table" then old.Lock else nil
			if type(lock) == "table" and lock.JobId == JOB_ID then
				old.Lock = nil
				return old
			end
			return nil
		end)
		profile.released = true
		profile.status = "failed"
		return profile
	end

	if data.Coins ~= nil then
		profile.coins = asNumber(data.Coins, 0, MAX_COINS, GameConfig.StartingCoins)
	end
	profile.speed = asNumber(data.Speed, 0, #GameConfig.SpeedLevelCosts, 0)
	profile.park = sanitizePark(data)
	profile.status = "ok"
	return profile
end

local function isHost(player: Player): boolean
	return hostPlayer == player
end

-- Writes a profile. `release` also drops the session lock (the player is leaving or the server is closing).
local function saveProfile(profile: Profile, release: boolean): boolean
	if profile.status ~= "ok" or profile.released then
		return false
	end
	if profile.saving and not release then
		return false
	end
	while profile.saving do
		task.wait(0.1)
	end
	profile.saving = true
	profile.dirty = false
	profile.urgent = false

	local coins = currentCoins(profile.player) or profile.lastCoins
	profile.lastCoins = coins
	local snapshot = if isHost(profile.player) and collectPark then collectPark() else nil
	local lostLock = false

	local ok, result = attempt(function()
		return (ensureBackend()).update(profile.key, function(old: any): any
			local lock = if type(old) == "table" then old.Lock else nil
			if type(lock) == "table" and lock.JobId ~= JOB_ID and os.time() - (lock.Time or 0) < LOCK_SECONDS then
				lostLock = true
				return nil
			end
			local record = if type(old) == "table" then old else {}
			record.Version = SAVE_VERSION
			record.Coins = coins
			record.Speed = profile.speed
			if snapshot then
				record.Park = snapshot.Park
				record.Rides = snapshot.Rides
				record.Janitors = snapshot.Janitors
			end
			record.Lock = if release then nil else { JobId = JOB_ID, Time = os.time() }
			return record
		end)
	end, SAVE_ATTEMPTS)

	profile.saving = false
	if lostLock then
		profile.status = "failed"
		warn(
			string.format(
				"[ParkPark] %s's save is now held by another server; this session stops saving it",
				profile.player.Name
			)
		)
		return false
	end
	if not ok then
		profile.dirty = true
		warn(string.format("[ParkPark] Could not save %s's progress (%s)", profile.player.Name, tostring(result)))
		return false
	end
	profile.lastSave = os.clock()
	if release then
		profile.released = true
	end
	return true
end

-- Coins for a joining player: the saved balance, or nil for the starting amount.
function PersistenceService.LoadCoins(player: Player): number?
	local profile = loadProfile(player)
	return profile.coins
end

-- A player's speed-shop level (saved with their coins).
function PersistenceService.GetSpeedLevel(player: Player): number
	local profile = profiles[player]
	return if profile then profile.speed else 0
end

function PersistenceService.SetSpeedLevel(player: Player, level: number)
	local profile = profiles[player]
	if profile and profile.status == "ok" then
		profile.speed = math.clamp(level, 0, #GameConfig.SpeedLevelCosts)
		profile.dirty = true
		profile.urgent = true
	end
end

-- Waits for the first player, makes them the host, and returns the park they saved (nil for a new park or a
-- failed load). Call before the park is built.
function PersistenceService.LoadParkState(): SavedState?
	while #Players:GetPlayers() == 0 do
		Players.PlayerAdded:Wait()
	end
	local host = Players:GetPlayers()[1]
	hostPlayer = host
	local profile = loadProfile(host)
	return if profile.status == "ok" then profile.park else nil
end

local function markDirty(player: Player, urgent: boolean)
	local profile = profiles[player]
	if profile and profile.status == "ok" then
		profile.dirty = true
		profile.urgent = profile.urgent or urgent
	end
end

local function markParkDirty()
	if hostPlayer then
		markDirty(hostPlayer, true)
	end
end

-- The host is the player whose profile receives the park snapshot; pick the first player whose save loaded.
local function pickHost(excluded: Player?)
	local chosen: Player? = nil
	for _, other in Players:GetPlayers() do
		local otherProfile = profiles[other]
		if other ~= excluded and otherProfile and otherProfile.status == "ok" then
			chosen = other
			break
		end
	end
	hostPlayer = chosen
	if chosen then
		markDirty(chosen, true)
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile == nil then
		return
	end
	if profile.status == "ok" then
		saveProfile(profile, true)
	end
	profiles[player] = nil
	if hostPlayer == player then
		pickHost(player)
	end
end
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Starts autosaving. `collect` reads the park's current state; `watch` lists the instances whose attributes
-- (ride models and the park folder) mean the park changed, so a save follows soon after.
function PersistenceService.Start(collect: () -> SavedState, watch: { Instance })
	collectPark = collect
	for _, instance in watch do
		instance.AttributeChanged:Connect(function(name: string)
			if name ~= "IsOperating" and name ~= "QueueLength" and name ~= "Boardings" and name ~= "Occupants" then
				markParkDirty()
			end
		end)
	end

	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			local now = os.clock()
			local currentHost = hostPlayer
			local hostProfile = if currentHost then profiles[currentHost] else nil
			if hostProfile == nil or hostProfile.status == "failed" then
				pickHost(currentHost)
			end
			for player, profile in profiles do
				if profile.status == "ok" and not profile.released then
					local coins = currentCoins(player)
					if coins and coins ~= profile.lastCoins then
						profile.lastCoins = coins
						profile.dirty = true
					end
					local gap = if profile.urgent then URGENT_GAP else NORMAL_GAP
					if (profile.dirty and now - profile.lastSave >= gap) or now - profile.lastSave >= REFRESH_GAP then
						task.spawn(saveProfile, profile, false)
					end
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, profile in profiles do
			if profile.status == "ok" and not profile.released then
				pending += 1
				task.spawn(function()
					saveProfile(profile, true)
					pending -= 1
				end)
			end
		end
		local waited = 0
		while pending > 0 and waited < CLOSE_WAIT do
			waited += task.wait(0.25)
		end
	end)
end

-- Saves every profile now (used by tests); returns how many were written.
function PersistenceService.SaveAll(): number
	local written = 0
	for _, profile in profiles do
		if saveProfile(profile, false) then
			written += 1
		end
	end
	return written
end

-- Test helper: forgets the stored profile of a user, and stops this server from writing it again.
function PersistenceService.Reset(userId: number)
	local key = "Player_" .. tostring(userId)
	ensureBackend().remove(key)
	memory[key] = nil
	for _, profile in profiles do
		if profile.key == key then
			profile.status = "failed"
		end
	end
end

-- Test helper: a copy of what is stored for a user right now (nil if nothing).
function PersistenceService.Peek(userId: number): any
	local result: any = nil
	ensureBackend().update("Player_" .. tostring(userId), function(old: any): any
		result = deepCopy(old)
		return nil
	end)
	return result
end

function PersistenceService.Mode(): string
	return ensureBackend().name
end

return PersistenceService
