--!strict

local GameConfig = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("ParkRebornShared")
		:WaitForChild("Config")
		:WaitForChild("GameConfig")
)

-- What the player's own work is worth: seconds of the park's current income. Every active payout (gathering,
-- fishing, deliveries) is `seconds` of the summed IncomePerMinute of all repaired attractions, so it scales with
-- the park and never outgrows it; a small floor keeps the very first minutes from paying 1 coin.
local ActiveIncome = {}

function ActiveIncome.PerMinute(folder: Folder): number
	local total = 0
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("IsRepaired") == true then
			total += (child:GetAttribute("IncomePerMinute") :: number?) or 0
		end
	end
	return total
end

function ActiveIncome.Value(folder: Folder, seconds: number): number
	local boost = (folder:GetAttribute("ActiveMultiplier") :: number?) or 1
	return math.max(
		GameConfig.Active.MinimumPayout,
		math.floor(ActiveIncome.PerMinute(folder) / 60 * seconds * boost + 0.5)
	)
end

return ActiveIncome
