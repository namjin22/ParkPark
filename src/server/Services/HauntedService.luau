--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Makes the haunted house feel alive: its WindowLight markers glow a soft gold while it runs and flicker in
-- eerie colours when guests are inside (`Occupants` on the house, kept by GuestService). Without power, or
-- before it is repaired, the windows are dark. Visual only.
local HauntedService = {}

type HauntedReferences = {
	ParkFolder: Folder,
	HauntedHouse: Model,
}

local IDLE_COLOR = GameConfig.Palette.Gold
local SPOOKY_COLORS = {
	Color3.fromRGB(150, 255, 170),
	Color3.fromRGB(255, 160, 90),
	Color3.fromRGB(190, 170, 255),
	Color3.fromRGB(255, 240, 200),
}

function HauntedService.Start(park: HauntedReferences)
	local house = park.HauntedHouse
	local windows: { BasePart } = {}
	for _, descendant in house:GetDescendants() do
		if descendant:IsA("BasePart") and string.match(descendant.Name, "^WindowLight%d+$") then
			-- The marker itself may be invisible (authored houses use plain markers); the light does the work.
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			if descendant:FindFirstChildOfClass("PointLight") == nil then
				local light = Instance.new("PointLight")
				light.Range = 22
				light.Brightness = 0
				light.Shadows = false
				light.Parent = descendant
			end
			table.insert(windows, descendant)
		end
	end
	if #windows == 0 then
		return
	end

	task.spawn(function()
		while park.ParkFolder.Parent ~= nil do
			local operating = house:GetAttribute("IsOperating") == true
			local occupants = (house:GetAttribute("Occupants") :: number?) or 0
			for _, window in windows do
				local light = window:FindFirstChildOfClass("PointLight")
				if light then
					if not operating then
						light.Brightness = 0
					elseif occupants > 0 then
						light.Color = SPOOKY_COLORS[math.random(1, #SPOOKY_COLORS)]
						light.Brightness = if math.random() < 0.25 then 0 else 1.5 + math.random() * 2
					else
						light.Color = IDLE_COLOR
						light.Brightness = 1
					end
					if window.Transparency < 1 then
						window.Color = light.Color
						window.Material = if light.Brightness > 0.4
							then Enum.Material.Neon
							else Enum.Material.SmoothPlastic
					end
				end
			end
			task.wait(if occupants > 0 then 0.15 + math.random() * 0.35 else 0.8)
		end
	end)
end

return HauntedService
