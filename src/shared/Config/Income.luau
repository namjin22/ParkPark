--!strict

local GameConfig = require(script.Parent.GameConfig)

-- Ride income. Attractions earn a steady flow of coins every second while they are repaired, running (power on,
-- park open) and, for guests to ride, visited; the guests are just there to look busy. A ride's flow in coins per
-- minute is its fare (the old per-guest price, now just a grade of how good the ride is, plus the income upgrades)
-- times a factor that shrinks along the unlock chain, because later rides share the same crowd, times a bonus per
-- staff level. The factor is `IncomeScale` x half the guests the park holds with n rides, divided by n, which
-- keeps the park's total flow close to what the guest-count model predicts at every stage.
local Income = {}

local chainIndex: { [string]: number } = {}
for index, key in GameConfig.RideChain do
	chainIndex[key] = index
end

function Income.Factor(rideKey: string): number
	local n = chainIndex[rideKey] or 1
	local guests = math.min(GameConfig.MaxGuests + GameConfig.GuestsPerRide * n, GameConfig.MaxGuestsCap)
	return GameConfig.IncomeScale * 0.5 * guests / n
end

-- Coins per minute for a ride at the given income and staff levels (before park-wide multipliers).
function Income.PerMinute(rideKey: string, incomeLevel: number, staffLevel: number): number
	local config = GameConfig.Rides[rideKey]
	local fare = config.BaseFare + incomeLevel * config.IncomePerLevel
	return fare * Income.Factor(rideKey) * (1 + GameConfig.StaffIncomeBonus * staffLevel)
end

return Income
