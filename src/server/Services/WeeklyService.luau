--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActiveIncome = require(script.Parent.ActiveIncome)
local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Weekly goals: each (UTC) week every player gets one big goal per activity (gathering, fishing, delivering,
-- playing the plaza booths), with the tier drawn from the week number so everyone sees the same ones. Unlike the
-- daily missions the counts are saved, so a week's progress survives leaving the game. A finished goal pays minutes
-- of the park's income once (the bit stays set for the week). The player attributes `Weekly1..4` carry
-- "text|progress|goal|reward|done" for the missions panel. MissionService.Report forwards every activity here.
local WeeklyService = {}

type AwardCoins = (Player, number) -> boolean
type Notify = (Player, string, string) -> ()
type Counts = { [string]: number }
type GetState = (Player) -> (number, number, Counts)
type SetState = (Player, number, number, Counts) -> ()

local WEEK = 604800

local started = false
local folderRef: Folder? = nil
local awardRef: AwardCoins? = nil
local notifyRef: Notify? = nil
local setStateRef: SetState? = nil
local doneMask: { [Player]: number } = {}
local counts: { [Player]: Counts } = {}
local playerWeek: { [Player]: number } = {}

local function weekMissions(week: number): { { kind: string, goal: number, minutes: number, text: string } }
	local random = Random.new(week)
	local list = {}
	for _, kind in GameConfig.WeeklyOrder do
		local pool = GameConfig.Weekly[kind]
		local entry = pool[random:NextInteger(1, #pool)]
		table.insert(list, { kind = kind, goal = entry.Goal, minutes = entry.Minutes, text = entry.Text })
	end
	return list
end

local function publish(player: Player)
	local folder = folderRef
	if folder == nil or doneMask[player] == nil then
		return
	end
	local mask = doneMask[player]
	local mine = counts[player] or {}
	for index, goal in weekMissions(os.time() // WEEK) do
		local reward = ActiveIncome.Value(folder, goal.minutes * 60)
		local done = bit32.band(mask, bit32.lshift(1, index - 1)) ~= 0
		local shown = if done then goal.goal else math.min(mine[goal.kind] or 0, goal.goal)
		player:SetAttribute(
			"Weekly" .. index,
			string.format("%s|%d|%d|%d|%d", goal.text, shown, goal.goal, reward, if done then 1 else 0)
		)
	end
end

function WeeklyService.Report(player: Player, kind: string)
	if not started or doneMask[player] == nil then
		return
	end
	local folder, award, notify, setState = folderRef, awardRef, notifyRef, setStateRef
	if folder == nil or award == nil or notify == nil or setState == nil then
		return
	end
	local week = os.time() // WEEK
	if playerWeek[player] ~= week then
		-- A new week began while the player was in the game.
		playerWeek[player] = week
		doneMask[player] = 0
		counts[player] = {}
	end
	local mine = counts[player]
	if mine == nil then
		mine = {}
		counts[player] = mine
	end
	local changed = false
	for index, goal in weekMissions(week) do
		local bitValue = bit32.lshift(1, index - 1)
		if goal.kind == kind and bit32.band(doneMask[player], bitValue) == 0 then
			mine[kind] = (mine[kind] or 0) + 1
			changed = true
			if mine[kind] >= goal.goal then
				doneMask[player] = bit32.bor(doneMask[player], bitValue)
				local reward = ActiveIncome.Value(folder, goal.minutes * 60)
				award(player, reward)
				notify(
					player,
					"주간 목표 완료",
					string.format("%s · +%d %s", goal.text, reward, GameConfig.CurrencyDisplayName)
				)
			end
		end
	end
	if changed then
		setState(player, week, doneMask[player], mine)
		publish(player)
	end
end

function WeeklyService.Start(
	park: { ParkFolder: Folder },
	awardCoins: AwardCoins,
	notify: Notify,
	getState: GetState,
	setState: SetState
)
	started = true
	folderRef = park.ParkFolder
	awardRef = awardCoins
	notifyRef = notify
	setStateRef = setState

	local function onPlayer(player: Player)
		task.spawn(function()
			-- The saved state is loaded before leaderstats appears.
			player:WaitForChild("leaderstats", 30)
			if player.Parent == nil then
				return
			end
			local week, mask, saved = getState(player)
			local current = os.time() // WEEK
			playerWeek[player] = current
			if week == current then
				doneMask[player] = mask
				counts[player] = saved
			else
				doneMask[player] = 0
				counts[player] = {}
			end
			publish(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		doneMask[player] = nil
		counts[player] = nil
		playerWeek[player] = nil
	end)
	-- Rewards follow the park's income, and a new week starts without a rejoin.
	task.spawn(function()
		while park.ParkFolder.Parent ~= nil do
			task.wait(30)
			local week = os.time() // WEEK
			for _, player in Players:GetPlayers() do
				if doneMask[player] ~= nil then
					if playerWeek[player] ~= week then
						playerWeek[player] = week
						doneMask[player] = 0
						counts[player] = {}
					end
					publish(player)
				end
			end
		end
	end)
end

return WeeklyService
