--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- The speed shop's prompt text is the same for everyone on the server, so each client rewrites it from the
-- local player's own `SpeedLevel` attribute: the next level and its price, or "max".
local SpeedShopController = {}

function SpeedShopController.Start()
	local player = Players.LocalPlayer
	local park = Workspace:WaitForChild("ParkParkWorld")
	local shop = park:WaitForChild("SpeedShop", 30)
	if shop == nil then
		warn("[ParkPark] Speed shop did not replicate to the client")
		return
	end
	local counter = shop:WaitForChild("Counter", 30)
	if counter == nil or not counter:IsA("BasePart") then
		warn("[ParkPark] Speed shop counter did not replicate to the client")
		return
	end
	local prompt = counter:WaitForChild("SpeedPrompt", 30)
	if prompt == nil or not prompt:IsA("ProximityPrompt") then
		warn("[ParkPark] Speed shop prompt did not replicate to the client")
		return
	end

	local function refresh()
		local level = (player:GetAttribute("SpeedLevel") :: number?) or 0
		local cost = GameConfig.SpeedLevelCosts[level + 1]
		if cost then
			prompt.ActionText = string.format("속도 %d단계로 올리기", level + 1)
			prompt.ObjectText = string.format("%d %s", cost, GameConfig.CurrencyDisplayName)
		else
			prompt.ActionText = "최고 속도예요"
			prompt.ObjectText = "속도 신발 상점"
		end
	end
	player:GetAttributeChangedSignal("SpeedLevel"):Connect(refresh)
	refresh()
end

return SpeedShopController
