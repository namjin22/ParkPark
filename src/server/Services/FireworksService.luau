--!strict

local Debris = game:GetService("Debris")

-- Night fireworks: while the park attribute `Night` is true, a burst of coloured sparks goes off above the plaza
-- every few seconds (an invisible part with a one-shot particle emitter, removed after the sparks fade).
local FireworksService = {}

local COLORS = {
	Color3.fromRGB(255, 120, 110),
	Color3.fromRGB(255, 210, 90),
	Color3.fromRGB(130, 220, 190),
	Color3.fromRGB(150, 170, 255),
	Color3.fromRGB(255, 160, 220),
}

local function burst(parent: Instance, position: Vector3, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Name = "Firework"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Parent = parent

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color, Color3.fromRGB(255, 255, 255))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4), NumberSequenceKeypoint.new(1, 0.2) })
	emitter.Lifetime = NumberRange.new(1.6, 2.4)
	emitter.Speed = NumberRange.new(26, 42)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 3
	emitter.Acceleration = Vector3.new(0, -9, 0)
	emitter.LightEmission = 1
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Parent = anchor
	emitter:Emit(70)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 40
	light.Brightness = 3
	light.Parent = anchor
	Debris:AddItem(anchor, 4)
end

function FireworksService.Start(park: { ParkFolder: Folder })
	local folder = park.ParkFolder
	task.spawn(function()
		local random = Random.new()
		while folder.Parent ~= nil do
			task.wait(random:NextNumber(3.5, 7))
			if folder:GetAttribute("Night") == true then
				local position =
					Vector3.new(random:NextNumber(-45, 75), random:NextNumber(55, 85), random:NextNumber(35, 110))
				burst(folder, position, COLORS[random:NextInteger(1, #COLORS)])
			end
		end
	end)
end

return FireworksService
