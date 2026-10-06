--!strict

local Players = game:GetService("Players")

-- Pays the ride income: once a second every repaired, running attraction adds its coins-per-minute flow
-- (`IncomePerMinute`, published by RideService) to every player, times the park-wide multipliers (events, night,
-- decor plots). Fractions are carried over so slow early rides still pay out exactly. Every few seconds a small
-- "+N" floats over each ride that has a player nearby, so the flow is visible where it comes from.
local IncomeService = {}

type AwardCoins = (Player, number) -> boolean
type Popup = (Vector3, string) -> ()

local TICK = 1
local POPUP_SECONDS = 6
local POPUP_RANGE = 110

function IncomeService.Start(park: { ParkFolder: Folder }, gameConfig: any, awardCoins: AwardCoins, popup: Popup)
	local folder = park.ParkFolder
	local carry: { [Player]: number } = {}
	local rideCarry: { [Instance]: number } = {}
	local lastPopup: { [Instance]: number } = {}

	local function multiplier(): number
		local result = (folder:GetAttribute("FareMultiplier") :: number?) or 1
		if folder:GetAttribute("Night") == true then
			result *= gameConfig.NightFareMultiplier
		end
		result *= 1 + ((folder:GetAttribute("PlotsBought") :: number?) or 0) * gameConfig.DecorPlotFareBonus
		-- Playing together pays: every extra player in the park adds PartyBonusPerPlayer, up to PartyBonusMax.
		local party =
			math.min(gameConfig.PartyBonusMax, math.max(0, #Players:GetPlayers() - 1) * gameConfig.PartyBonusPerPlayer)
		folder:SetAttribute("PartyBonus", party)
		result *= 1 + party
		return result
	end

	task.spawn(function()
		while folder.Parent ~= nil do
			task.wait(TICK)
			if folder:GetAttribute("ParkOpen") == true then
				local factor = multiplier() / 60 * TICK
				local total = 0
				local now = os.clock()
				for _, ride in folder:GetChildren() do
					if
						ride:IsA("Model")
						and ride:GetAttribute("IsRepaired") == true
						and ride:GetAttribute("IsOperating") == true
					then
						local perMinute = ride:GetAttribute("IncomePerMinute")
						if type(perMinute) == "number" and perMinute > 0 then
							local earned = perMinute * factor
							total += earned
							rideCarry[ride] = (rideCarry[ride] or 0) + earned
							if now - (lastPopup[ride] or 0) >= POPUP_SECONDS then
								lastPopup[ride] = now
								local amount = math.floor(rideCarry[ride] + 0.5)
								rideCarry[ride] = 0
								local pivot = ride:GetPivot().Position + Vector3.new(0, 16, 0)
								local near = false
								for _, player in Players:GetPlayers() do
									local root = player.Character
										and player.Character:FindFirstChild("HumanoidRootPart")
									if
										root
										and root:IsA("BasePart")
										and (root.Position - pivot).Magnitude <= POPUP_RANGE
									then
										near = true
										break
									end
								end
								if near and amount > 0 then
									popup(pivot, string.format("+%d", amount))
								end
							end
						end
					end
				end
				if total > 0 then
					for _, player in Players:GetPlayers() do
						local owed = (carry[player] or 0) + total
						local whole = math.floor(owed)
						carry[player] = owed - whole
						if whole > 0 then
							awardCoins(player, whole)
						end
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		carry[player] = nil
	end)
end

return IncomeService
