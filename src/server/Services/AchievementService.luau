--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActiveIncome = require(script.Parent.ActiveIncome)
local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Achievements (GameConfig.Achievements): lifetime counters per player (gathering, fishing, deliveries, booth plays)
-- and park milestones (repaired attractions, open zones, guests boarded, landmarks, decor plots). Each is paid once
-- with minutes of the park's income, some also give a reward-only title (CosmeticsService.Grant). The lifetime
-- counters and the unlocked ids are saved with the profile. The player attribute `Achievements` carries
-- "name|progress|target|done" entries joined by ";" for the client list. MissionService.Report forwards activities.
local AchievementService = {}

type AwardCoins = (Player, number) -> boolean
type Notify = (Player, string, string) -> ()
type Stats = { [string]: number }
type GetState = (Player) -> (Stats, { string })
type SetState = (Player, Stats, { string }) -> ()
type Grant = (Player, string) -> boolean

local started = false
local stats: { [Player]: Stats } = {}
local unlocked: { [Player]: { [string]: boolean } } = {}
local evaluateRef: ((Player) -> ())? = nil
local persistRef: ((Player) -> ())? = nil

function AchievementService.Report(player: Player, kind: string)
	if not started or stats[player] == nil then
		return
	end
	local mine = stats[player]
	mine[kind] = math.min((mine[kind] or 0) + 1, 1e7)
	-- Counters are saved on every report (the autosave batches them), not only when something unlocks.
	if persistRef then
		persistRef(player)
	end
	if evaluateRef then
		evaluateRef(player)
	end
end

function AchievementService.Start(
	park: { ParkFolder: Folder },
	awardCoins: AwardCoins,
	notify: Notify,
	getState: GetState,
	setState: SetState,
	grant: Grant
)
	local folder = park.ParkFolder
	started = true

	local function target(def: any): number
		if def.Target > 0 then
			return def.Target
		end
		if def.Kind == "Rides" then
			return #GameConfig.RideChain
		elseif def.Kind == "Zones" then
			return #GameConfig.ZoneOrder
		end
		return 1
	end

	local function value(def: any, player: Player): number
		local kind = def.Kind
		if kind == "Rides" then
			local count = 0
			for _, child in folder:GetChildren() do
				if child:IsA("Model") and child:GetAttribute("IsRepaired") == true then
					count += 1
				end
			end
			return count
		elseif kind == "Zones" then
			local count = 0
			for _, zone in GameConfig.ZoneOrder do
				if folder:GetAttribute("Zone_" .. zone) == true then
					count += 1
				end
			end
			return count
		elseif kind == "Boarded" then
			return (folder:GetAttribute("GuestsBoarded") :: number?) or 0
		elseif kind == "Landmarks" then
			local total = 0
			for key in GameConfig.Landmarks do
				total += (folder:GetAttribute("Landmark_" .. key) :: number?) or 0
			end
			return total
		elseif kind == "Plots" then
			return (folder:GetAttribute("PlotsBought") :: number?) or 0
		end
		return (stats[player] or {})[kind] or 0
	end

	local function persist(player: Player)
		local ids: { string } = {}
		local mine: { [string]: boolean } = unlocked[player] or {}
		for id in mine do
			table.insert(ids, id)
		end
		table.sort(ids)
		setState(player, stats[player] or {}, ids)
	end

	local function publish(player: Player)
		local entries = {}
		local mine = unlocked[player] or {}
		for _, def in GameConfig.Achievements do
			local goal = target(def)
			local done = mine[def.Id] == true
			local shown = if done then goal else math.min(value(def, player), goal)
			table.insert(entries, string.format("%s|%d|%d|%d", def.Name, shown, goal, if done then 1 else 0))
		end
		player:SetAttribute("Achievements", table.concat(entries, ";"))
	end

	local function evaluate(player: Player)
		local mine = unlocked[player]
		if mine == nil then
			return
		end
		local changed = false
		for _, def in GameConfig.Achievements do
			if not mine[def.Id] and value(def, player) >= target(def) then
				-- A reward title that cannot be given yet (closet still loading) postpones the whole unlock.
				if def.Title and not grant(player, def.Title) then
					continue
				end
				mine[def.Id] = true
				changed = true
				local reward = ActiveIncome.Value(folder, def.Minutes * 60)
				awardCoins(player, reward)
				notify(
					player,
					"업적 달성",
					string.format("%s · +%d %s", def.Name, reward, GameConfig.CurrencyDisplayName)
				)
			end
		end
		if changed then
			persist(player)
		end
		publish(player)
	end

	evaluateRef = evaluate
	persistRef = persist

	local function onPlayer(player: Player)
		task.spawn(function()
			-- The saved state is loaded before leaderstats appears.
			player:WaitForChild("leaderstats", 30)
			if player.Parent == nil then
				return
			end
			local savedStats, ids = getState(player)
			stats[player] = savedStats
			local set: { [string]: boolean } = {}
			for _, id in ids do
				set[id] = true
			end
			unlocked[player] = set
			-- Milestones already reached before this feature existed are paid on the first check.
			publish(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		stats[player] = nil
		unlocked[player] = nil
	end)

	-- Park milestones change without a player action, so check everyone now and then.
	task.spawn(function()
		while folder.Parent ~= nil do
			task.wait(10)
			for _, player in Players:GetPlayers() do
				if unlocked[player] ~= nil then
					evaluate(player)
				end
			end
		end
	end)
end

return AchievementService
