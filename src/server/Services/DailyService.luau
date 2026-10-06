--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))

-- Daily bonus: the first time a player joins on a new (UTC) day they get coins, with a streak of up to seven days
-- (a missed day starts again at day one). The reward scales with the park: DailyFareShare times the fares of
-- every repaired attraction, at least DailyMinimum, times the streak multiplier.
local DailyService = {}

type GetDaily = (Player) -> (number, number)
type SetDaily = (Player, number, number) -> ()

local DAY = 86400

function DailyService.Reward(park: { ParkFolder: Folder }, streak: number): number
	local total = 0
	for _, child in park.ParkFolder:GetChildren() do
		if child:GetAttribute("IsRepaired") == true then
			total += (child:GetAttribute("Fare") :: number?) or 0
		end
	end
	local base = math.max(GameConfig.DailyMinimum, math.floor(total * GameConfig.DailyFareShare))
	local multiplier = GameConfig.DailyStreakMultipliers[streak] or 1
	local reward = math.floor(base * multiplier / 10 + 0.5) * 10
	return math.min(GameConfig.DailyMaximum, reward)
end

function DailyService.Start(
	park: { ParkFolder: Folder },
	awardCoins: (Player, number) -> boolean,
	notify: (Player, string, string) -> (),
	getDaily: GetDaily,
	setDaily: SetDaily
)
	local function onPlayer(player: Player)
		task.spawn(function()
			-- The saved day is loaded before leaderstats appears; wait a moment so the toast is not lost.
			player:WaitForChild("leaderstats", 30)
			task.wait(6)
			if player.Parent == nil then
				return
			end
			local today = os.time() // DAY
			local lastDay, streak = getDaily(player)
			if lastDay == today then
				return
			end
			if lastDay == today - 1 and streak > 0 then
				streak = math.min(streak + 1, #GameConfig.DailyStreakMultipliers)
			else
				streak = 1
			end
			setDaily(player, today, streak)
			local reward = DailyService.Reward(park, streak)
			awardCoins(player, reward)
			notify(
				player,
				string.format("출석 %d일째", streak),
				string.format("출석 보너스 +%d %s", reward, GameConfig.CurrencyDisplayName)
			)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return DailyService
