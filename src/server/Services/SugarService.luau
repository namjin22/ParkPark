--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Slowly falling pastel sugar dust over the candy zone: an invisible slab high above it with a soft emitter.
local SugarService = {}

function SugarService.Start(park: { ParkFolder: Folder })
	local candy = ParkLayout.ZoneBounds.Candy
	local depth = candy.BoundaryZ - candy.MinZ
	local slab = Instance.new("Part")
	slab.Name = "SugarDust"
	slab.Size = Vector3.new(ParkLayout.GroundHalfWidth * 2, 1, depth)
	slab.Position = Vector3.new(0, 55, (candy.BoundaryZ + candy.MinZ) / 2)
	slab.Anchored = true
	slab.CanCollide = false
	slab.CanQuery = false
	slab.CanTouch = false
	slab.Transparency = 1
	slab.Parent = park.ParkFolder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 190, 215), Color3.fromRGB(190, 240, 225))
	emitter.Size = NumberSequence.new(0.8)
	emitter.Lifetime = NumberRange.new(8, 11)
	emitter.Rate = 110
	emitter.Speed = NumberRange.new(4, 6)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.LightEmission = 0.5
	emitter.Parent = slab
end

return SugarService
