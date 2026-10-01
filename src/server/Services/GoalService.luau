--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Guest milestones (GameConfig.Goals): when the park's boarded-guest count reaches the next goal, every player
-- receives its reward. How many goals are claimed is the park attribute `GoalsClaimed`, which is saved with
-- the park, so a restart never pays a goal twice.
local GoalService = {}

type AwardCoins = (Player, number) -> boolean
type Notify = (Player, string, string) -> ()

function GoalService.Start(park: { ParkFolder: Folder }, awardCoins: AwardCoins, notify: Notify)
	local folder = park.ParkFolder
	if folder:GetAttribute("GoalsClaimed") == nil then
		folder:SetAttribute("GoalsClaimed", 0)
	end

	local function check()
		while true do
			local claimed = (folder:GetAttribute("GoalsClaimed") :: number?) or 0
			local goal = GameConfig.Goals[claimed + 1]
			local boarded = (folder:GetAttribute("GuestsBoarded") :: number?) or 0
			if goal == nil or boarded < goal.Boarded then
				return
			end
			folder:SetAttribute("GoalsClaimed", claimed + 1)
			for _, player in Players:GetPlayers() do
				awardCoins(player, goal.Reward)
				notify(
					player,
					string.format("목표 달성! 손님 %d명", goal.Boarded),
					string.format("+%d %s", goal.Reward, GameConfig.CurrencyDisplayName)
				)
			end
		end
	end

	folder:GetAttributeChangedSignal("GuestsBoarded"):Connect(check)
	check()
end

return GoalService
