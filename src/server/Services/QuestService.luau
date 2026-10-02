--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- One quest at a time (GameConfig.Quests, in order). The current quest is published on the park folder
-- (`QuestTitle`, `QuestDesc`, `QuestProgress`, `QuestTarget`, `QuestReward`) for the client's quest card; how many
-- are done is `QuestIndex`, which is saved with the park. Counter quests count a park attribute from zero when
-- the quest starts; Ride quests count that ride's `Boardings`; Visit quests need a player to stand at a place;
-- Operating quests need that many rides running at once.
local QuestService = {}

type AwardCoins = (Player, number) -> boolean
type Notify = (Player, string, string) -> ()

function QuestService.Start(
	park: { ParkFolder: Folder },
	rideModels: { [string]: Model },
	awardCoins: AwardCoins,
	notify: Notify
)
	local folder = park.ParkFolder
	if folder:GetAttribute("QuestIndex") == nil then
		folder:SetAttribute("QuestIndex", 0)
	end

	local activeIndex = -1
	local base = 0
	local dwell = 0

	local function clear()
		for _, name in { "QuestTitle", "QuestDesc", "QuestProgress", "QuestTarget", "QuestReward" } do
			folder:SetAttribute(name, nil)
		end
	end

	local function operatingCount(): number
		local count = 0
		for _, model in rideModels do
			if model:GetAttribute("IsOperating") == true then
				count += 1
			end
		end
		return count
	end

	local function measure(quest: any): number
		if quest.Kind == "Counter" then
			return ((folder:GetAttribute(quest.Attr) :: number?) or 0) - base
		elseif quest.Kind == "Ride" then
			local model = rideModels[quest.Ride]
			return if model then ((model:GetAttribute("Boardings") :: number?) or 0) - base else 0
		elseif quest.Kind == "Operating" then
			return operatingCount()
		end
		return dwell
	end

	local function target(quest: any): number
		return if quest.Kind == "Visit" then quest.Seconds else quest.Target
	end

	local function startQuest(index: number)
		local quest: any = GameConfig.Quests[index]
		activeIndex = index
		dwell = 0
		if quest.Kind == "Counter" then
			base = (folder:GetAttribute(quest.Attr) :: number?) or 0
		elseif quest.Kind == "Ride" then
			local model = rideModels[quest.Ride :: string]
			base = if model then ((model:GetAttribute("Boardings") :: number?) or 0) else 0
		else
			base = 0
		end
		folder:SetAttribute("QuestTitle", quest.Title)
		folder:SetAttribute("QuestDesc", quest.Desc)
		folder:SetAttribute("QuestTarget", target(quest))
		folder:SetAttribute("QuestReward", quest.Reward)
		folder:SetAttribute("QuestProgress", 0)
	end

	local function complete(quest: any)
		folder:SetAttribute("QuestIndex", activeIndex)
		activeIndex = -1
		clear()
		for _, player in Players:GetPlayers() do
			awardCoins(player, quest.Reward)
			notify(
				player,
				string.format("퀘스트 완료! %s", quest.Title),
				string.format("+%d %s", quest.Reward, GameConfig.CurrencyDisplayName)
			)
		end
	end

	task.spawn(function()
		while folder.Parent ~= nil do
			local done = (folder:GetAttribute("QuestIndex") :: number?) or 0
			local quest: any = GameConfig.Quests[done + 1]
			if quest == nil then
				if activeIndex ~= -1 then
					activeIndex = -1
					clear()
				end
			elseif activeIndex ~= done + 1 then
				-- The next quest begins once the ride it needs has been repaired.
				local needed = quest.Requires and rideModels[quest.Requires]
				if quest.Requires == nil or (needed and needed:GetAttribute("IsRepaired") == true) then
					if folder:GetAttribute("EntranceCleared") == true then
						startQuest(done + 1)
					end
				end
			else
				if quest.Kind == "Visit" then
					local near = false
					for _, player in Players:GetPlayers() do
						local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
						if root and root:IsA("BasePart") then
							local offset = Vector3.new(root.Position.X - quest.X, 0, root.Position.Z - quest.Z)
							if offset.Magnitude <= quest.Radius then
								near = true
								break
							end
						end
					end
					dwell = if near then dwell + 1 else 0
				end
				local progress = math.max(0, math.floor(measure(quest)))
				folder:SetAttribute("QuestProgress", math.min(progress, target(quest)))
				if progress >= target(quest) then
					complete(quest)
				end
			end
			task.wait(1)
		end
	end)
end

return QuestService
