--!strict

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local ParkAccess = require(script.Parent.ParkAccess)
local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Personal parks. Every player owns a park that lives in a reserved server of their own (`Personal` mode):
--   * A player who joins the public place (the `Lobby`) is sent to their reserved server at once, or to a friend's
--     if they were invited (the invite's LaunchData or our TeleportData carries the friend's user id).
--   * In a reserved server the first player is the park's owner (ParkAccess); everyone else is a visitor who can
--     ride, gather and play but not manage, and earns a reduced share of the income.
--   * The access code of each owner's reserved server is kept in the DataStore `ParkParkServers`. Only friends of
--     the owner are sent there (checked with IsFriendsWith on the server), so a code is never given to a client.
--   * Anything that fails (no code, teleport error, Studio) leaves the player where they are with the old behaviour
--     (everyone may manage), so the game stays playable. In Studio nothing is teleported; decisions are logged.
local OwnerService = {}

type Notify = (Player, string, string) -> ()
type Entry = { userId: number, name: string }

local STORE_NAME = "ParkParkServers"
local STORE_SCOPE = "v1"
local VISIT_COOLDOWN = 5

local mode = "Studio"
local store: DataStore? = nil
local notifyRef: Notify? = nil
local lastVisit: { [Player]: number } = {}

function OwnerService.Mode(): string
	if RunService:IsStudio() then
		return "Studio"
	end
	if game.PrivateServerId ~= "" then
		-- A reserved server (ours) has no owner id; Roblox's own paid private servers do.
		if game.PrivateServerOwnerId == 0 then
			return "Personal"
		end
		return "VIPServer"
	end
	return "Lobby"
end

-- Which owner's park a joining player should end up in. Pure so it can be tested with made-up join data:
-- their own, unless the join carried a friend's user id (invite LaunchData or TeleportData.visitUserId).
function OwnerService.Decide(selfId: number, joinData: any, isFriend: (number) -> boolean): number
	if type(joinData) ~= "table" then
		return selfId
	end
	local wanted: number? = nil
	local teleportData = joinData.TeleportData
	if type(teleportData) == "table" and type(teleportData.visitUserId) == "number" then
		wanted = teleportData.visitUserId
	elseif type(joinData.LaunchData) == "string" then
		wanted = tonumber(joinData.LaunchData)
	end
	if wanted and wanted > 0 and wanted == math.floor(wanted) and wanted ~= selfId and isFriend(wanted) then
		return wanted
	end
	return selfId
end

local function getStore(): DataStore?
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME, STORE_SCOPE)
		end)
		if ok then
			store = result
		end
	end
	return store
end

local function lookupCode(ownerId: number): string?
	local dataStore = getStore()
	if dataStore == nil then
		return nil
	end
	local ok, value = pcall(function()
		return dataStore:GetAsync("Owner_" .. ownerId)
	end)
	if ok and type(value) == "table" and type(value.Code) == "string" then
		return value.Code
	end
	return nil
end

-- The player's own reserved server: looked up, or reserved now and stored (the first stored code wins when two
-- lobby servers race).
local function ensureCode(ownerId: number): string?
	local existing = lookupCode(ownerId)
	if existing then
		return existing
	end
	local dataStore = getStore()
	if dataStore == nil then
		return nil
	end
	local reserved, accessCode, serverId = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	if not reserved or type(accessCode) ~= "string" then
		warn("[ParkPark] Could not reserve a server for " .. tostring(ownerId))
		return nil
	end
	local ok, result = pcall(function()
		return dataStore:UpdateAsync("Owner_" .. ownerId, function(old: any): any
			if type(old) == "table" and type(old.Code) == "string" then
				return old
			end
			return { Code = accessCode, ServerId = serverId, Created = os.time() }
		end)
	end)
	if ok and type(result) == "table" and type(result.Code) == "string" then
		return result.Code
	end
	return nil
end

local function isFriendOf(player: Player, userId: number): boolean
	local ok, result = pcall(function()
		return player:IsFriendsWithAsync(userId)
	end)
	return ok and result == true
end

local function isPresent(player: Player): boolean
	return player:IsDescendantOf(Players)
end

local function say(player: Player, title: string, detail: string)
	if notifyRef then
		notifyRef(player, title, detail)
	end
end

-- Sends a player to an owner's reserved server. Returns whether the teleport was started; false leaves them here.
local function sendTo(player: Player, ownerId: number, code: string): boolean
	if mode == "Studio" then
		print(string.format("[ParkPark] (Studio) would send %s to %d's park", player.Name, ownerId))
		player:SetAttribute("LastRoute", ownerId)
		return false
	end
	local ok, err = pcall(function()
		TeleportService:TeleportToPrivateServer(game.PlaceId, code, { player }, nil, {
			ownerUserId = ownerId,
			visitUserId = if ownerId ~= player.UserId then ownerId else nil,
		})
	end)
	if not ok then
		warn(string.format("[ParkPark] Teleport for %s failed: %s", player.Name, tostring(err)))
	end
	return ok
end

-- Lobby: send a joining player to their park (or the friend's park they were invited to).
local function routeLobbyPlayer(player: Player)
	local retries = GameConfig.PersonalParks.TeleportRetries
	local joinData: any = nil
	pcall(function()
		joinData = player:GetJoinData()
	end)
	local target = OwnerService.Decide(player.UserId, joinData, function(userId: number)
		return isFriendOf(player, userId)
	end)
	for attempt = 1, retries + 1 do
		if not isPresent(player) then
			return
		end
		local code = if target == player.UserId then ensureCode(target) else lookupCode(target)
		if code == nil and target ~= player.UserId then
			-- The friend's park is not available: go to your own.
			target = player.UserId
			code = ensureCode(target)
		end
		if code and sendTo(player, target, code) then
			-- A started teleport removes the player; still here after a while means it did not go through.
			local waited = 0
			while isPresent(player) and waited < 20 do
				waited += task.wait(1)
			end
			if not isPresent(player) then
				return
			end
		end
		task.wait(2 * attempt)
	end
	if isPresent(player) then
		say(
			player,
			"공원 이동 실패",
			"이 서버에서 계속해요. 잠시 뒤 다시 들어오면 내 공원으로 가요"
		)
	end
end

local function friendParks(player: Player): { Entry }
	local list: { Entry } = {}
	local ok, friends = pcall(function()
		return player:GetFriendsOnlineAsync(100)
	end)
	if not ok or type(friends) ~= "table" then
		return list
	end
	for _, friend in friends do
		if type(friend) == "table" and friend.PlaceId == game.PlaceId and type(friend.VisitorId) == "number" then
			table.insert(list, { userId = friend.VisitorId, name = tostring(friend.UserName or friend.VisitorId) })
		end
	end
	return list
end

local function remoteNamed(events: Instance, name: string): RemoteEvent
	local existing = events:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = events
	return remote
end

-- `getHost` returns the player whose park this server shows (the first player).
function OwnerService.Start(park: { ParkFolder: Folder }, notify: Notify, getHost: () -> Player?)
	mode = OwnerService.Mode()
	notifyRef = notify
	local folder = park.ParkFolder
	local enabled = GameConfig.PersonalParks.Enabled
	local personal = enabled and mode == "Personal"
	-- Studio test hooks (ignored outside Studio): `DebugPersonalPark` turns the personal-park rules on, and
	-- `DebugVisitor` makes everyone a visitor of an absent owner (a single-player stand-in for a second player).
	local debugVisitor = false
	if mode == "Studio" and enabled then
		local storage = game:GetService("ServerStorage")
		local personalFlag = storage:FindFirstChild("DebugPersonalPark")
		local visitorFlag = storage:FindFirstChild("DebugVisitor")
		if personalFlag and personalFlag:IsA("BoolValue") and personalFlag.Value then
			personal = true
			debugVisitor = visitorFlag ~= nil and visitorFlag:IsA("BoolValue") and visitorFlag.Value
		end
	end
	ParkAccess.Configure(personal, notify)
	folder:SetAttribute("ParkMode", mode)

	local events = ReplicatedStorage:WaitForChild("ParkParkEvents")
	local requestList = remoteNamed(events, "RequestFriendParks")
	local listRemote = remoteNamed(events, "FriendParks")
	local visitRemote = remoteNamed(events, "VisitPark")

	local ownerName = ""
	local function refreshOwner()
		local owner = if debugVisitor then nil else getHost()
		if personal then
			ParkAccess.SetOwner(owner)
			if owner then
				ownerName = owner.DisplayName
				folder:SetAttribute("OwnerUserId", owner.UserId)
				folder:SetAttribute("OwnerName", ownerName)
			end
		end
		for _, player in Players:GetPlayers() do
			player:SetAttribute("IsVisitor", ParkAccess.IsVisitor(player))
		end
	end

	local function onPlayer(player: Player)
		if mode == "Lobby" and enabled then
			task.spawn(routeLobbyPlayer, player)
		end
		-- The host is known once the first profile is loaded; mark everyone again shortly after each join.
		task.defer(refreshOwner)
		task.delay(3, refreshOwner)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastVisit[player] = nil
		ParkAccess.Forget(player)
		if personal and ParkAccess.GetOwner() == player then
			-- The owner left: visitors can no longer change anything and are sent to their own parks shortly.
			for _, other in Players:GetPlayers() do
				if other ~= player then
					say(other, "주인이 떠났어요", "잠시 뒤 내 공원으로 돌아가요")
					task.delay(15, function()
						if isPresent(other) then
							local code = ensureCode(other.UserId)
							if code then
								sendTo(other, other.UserId, code)
							end
						end
					end)
				end
			end
		end
	end)
	refreshOwner()

	requestList.OnServerEvent:Connect(function(player: Player)
		listRemote:FireClient(player, friendParks(player), ownerName, ParkAccess.IsVisitor(player))
	end)

	visitRemote.OnServerEvent:Connect(function(player: Player, userId: unknown)
		if type(userId) ~= "number" or userId ~= math.floor(userId) or userId <= 0 then
			return
		end
		local now = os.clock()
		if now - (lastVisit[player] or 0) < VISIT_COOLDOWN then
			return
		end
		lastVisit[player] = now
		if not enabled then
			return
		end
		local target = userId
		if target ~= player.UserId and not isFriendOf(player, target) then
			say(player, "방문할 수 없어요", "친구의 공원만 방문할 수 있어요")
			return
		end
		local code = if target == player.UserId then ensureCode(target) else lookupCode(target)
		if code == nil then
			say(
				player,
				"공원을 찾지 못했어요",
				"친구가 한 번이라도 접속해야 공원이 만들어져요"
			)
			return
		end
		if not sendTo(player, target, code) and mode ~= "Studio" then
			say(player, "이동에 실패했어요", "잠시 뒤 다시 시도해 주세요")
		elseif mode == "Studio" then
			say(
				player,
				"Studio에서는 이동하지 않아요",
				string.format("%d의 공원으로 가는 요청만 확인했어요", target)
			)
		end
	end)
end

-- For tests: the JSON of what a join would be decided from.
function OwnerService.DebugDecide(selfId: number, json: string, friends: { number }): number
	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	return OwnerService.Decide(selfId, if ok then data else nil, function(userId: number)
		return table.find(friends, userId) ~= nil
	end)
end

return OwnerService
