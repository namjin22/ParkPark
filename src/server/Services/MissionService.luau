--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActiveIncome = require(script.Parent.ActiveIncome)
local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Daily missions: each (UTC) day every player gets three, one each for gathering, fishing and delivering, with a
-- difficulty picked from the day number so everyone sees the same three. Progress counts while the player is in the
-- server; a finished mission pays minutes of the park's income and is remembered for the day (saved with the
-- profile) so it cannot be repeated. The player attributes `Mission1..3` carry "text|progress|goal|reward|done"
-- for the client panel.
local MissionService = {}

type AwardCoins = (Player, number) -> boolean
type Notify = (Player, string, string) -> ()
type GetState = (Player) -> (number, number)
type SetState = (Player, number, number) -> ()

local DAY = 86400
local KINDS = { "Gather", "Fish", "Deliver" }

local started = false
local folderRef: Folder? = nil
local awardRef: AwardCoins? = nil
local notifyRef: Notify? = nil
local setStateRef: SetState? = nil
local progress: { [Player]: { [number]: number } } = {}
local doneMask: { [Player]: number } = {}

-- The three missions of a day: { kind, tier index in GameConfig.Missions[kind] } in a fixed order.
local function dayMissions(day: number): { { kind: string, tier: number, goal: number, minutes: number, text: string } }
	local random = Random.new(day)
	local list = {}
	for _, kind in KINDS do
		local pool = GameConfig.Missions[kind]
		local tier = random:NextInteger(1, #pool)
		local entry = pool[tier]
		table.insert(list, { kind = kind, tier = tier, goal = entry.Goal, minutes = entry.Minutes, text = entry.Text })
	end
	return list
end

local function publish(player: Player)
	local folder = folderRef
	if folder == nil then
		return
	end
	local list = dayMissions(os.time() // DAY)
	local mask = doneMask[player] or 0
	local counts = progress[player] or {}
	for index, mission in list do
		local reward = ActiveIncome.Value(folder, mission.minutes * 60)
		local done = bit32.band(mask, bit32.lshift(1, index - 1)) ~= 0
		local shown = if done then mission.goal else math.min(counts[index] or 0, mission.goal)
		player:SetAttribute(
			"Mission" .. index,
			string.format("%s|%d|%d|%d|%d", mission.text, shown, mission.goal, reward, if done then 1 else 0)
		)
	end
end

function MissionService.Report(player: Player, kind: string)
	if not started or doneMask[player] == nil then
		return
	end
	local folder, award, notify, setState = folderRef, awardRef, notifyRef, setStateRef
	if folder == nil or award == nil or notify == nil or setState == nil then
		return
	end
	local day = os.time() // DAY
	local list = dayMissions(day)
	local counts = progress[player]
	if counts == nil then
		counts = {}
		progress[player] = counts
	end
	for index, mission in list do
		local bitValue = bit32.lshift(1, index - 1)
		if mission.kind == kind and bit32.band(doneMask[player], bitValue) == 0 then
			counts[index] = (counts[index] or 0) + 1
			if counts[index] >= mission.goal then
				doneMask[player] = bit32.bor(doneMask[player], bitValue)
				local reward = ActiveIncome.Value(folder, mission.minutes * 60)
				award(player, reward)
				notify(
					player,
					"미션 완료",
					string.format("%s · +%d %s", mission.text, reward, GameConfig.CurrencyDisplayName)
				)
				setState(player, day, doneMask[player])
			end
		end
	end
	publish(player)
end

function MissionService.Start(
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
			local day, mask = getState(player)
			doneMask[player] = if day == os.time() // DAY then mask else 0
			progress[player] = {}
			publish(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		progress[player] = nil
		doneMask[player] = nil
	end)
	-- A park that grows during the day changes what a mission pays, so keep the shown rewards current.
	task.spawn(function()
		while park.ParkFolder.Parent ~= nil do
			task.wait(20)
			for _, player in Players:GetPlayers() do
				if doneMask[player] ~= nil then
					publish(player)
				end
			end
		end
	end)
end

return MissionService
