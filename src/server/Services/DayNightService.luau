--!strict

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- The sky turns through a full day every GameConfig.DayCycleSeconds. At night the park folder carries
-- `Night = true` (GuestService raises fares), the lamp posts glow, and players get a notice at dusk.
local DayNightService = {}

type Notify = (Player, string, string) -> ()

local TICK = 2

function DayNightService.Start(park: { ParkFolder: Folder }, notify: Notify)
	local folder = park.ParkFolder
	local hoursPerTick = 24 / GameConfig.DayCycleSeconds * TICK
	local night = false
	Lighting.ClockTime = 14

	local function isNight(hour: number): boolean
		return hour >= GameConfig.NightStartHour or hour < GameConfig.NightEndHour
	end

	local function setLamps(on: boolean)
		local decor = folder:FindFirstChild("Decor")
		if decor == nil then
			return
		end
		for _, lamp in decor:GetChildren() do
			if lamp.Name == "DecorLamp" and lamp:IsA("Model") then
				local light = lamp:FindFirstChild("NightLight", true)
				if light == nil then
					local anchor = lamp:FindFirstChildWhichIsA("BasePart", true)
					if anchor == nil then
						continue
					end
					local newLight = Instance.new("PointLight")
					newLight.Name = "NightLight"
					newLight.Color = Color3.fromRGB(255, 214, 150)
					newLight.Brightness = 2
					newLight.Range = 26
					newLight.Shadows = false
					newLight.Parent = anchor
					light = newLight
				end
				(light :: PointLight).Enabled = on
			end
		end
	end

	task.spawn(function()
		while folder.Parent ~= nil do
			Lighting.ClockTime = (Lighting.ClockTime + hoursPerTick) % 24
			local nowNight = isNight(Lighting.ClockTime)
			if nowNight ~= night then
				night = nowNight
				folder:SetAttribute("Night", night)
				setLamps(night)
				if night and folder:GetAttribute("ParkOpen") == true then
					for _, player in Players:GetPlayers() do
						notify(player, "야간 개장!", "밤에는 요금이 15% 올라요")
					end
				end
			end
			task.wait(TICK)
		end
	end)
end

return DayNightService
