--!strict

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

-- Dims the whole scene while the server reports a power outage (`PowerOut` on the park folder) and brings
-- the light back when it ends. Purely visual: the server owns the outage itself.
local PowerController = {}

function PowerController.Start()
	local world = workspace:WaitForChild("ParkParkWorld")

	local dusk = Instance.new("ColorCorrectionEffect")
	dusk.Name = "ParkParkOutage"
	dusk.Brightness = 0
	dusk.Contrast = 0
	dusk.Saturation = 0
	dusk.TintColor = Color3.new(1, 1, 1)
	dusk.Parent = Lighting

	local function apply()
		local out = world:GetAttribute("PowerOut") == true
		TweenService:Create(dusk, TweenInfo.new(if out then 1.2 else 0.8), {
			Brightness = if out then -0.22 else 0,
			Contrast = if out then 0.08 else 0,
			Saturation = if out then -0.25 else 0,
			TintColor = if out then Color3.fromRGB(150, 165, 230) else Color3.new(1, 1, 1),
		}):Play()
	end

	world:GetAttributeChangedSignal("PowerOut"):Connect(apply)
	apply()
end

return PowerController
