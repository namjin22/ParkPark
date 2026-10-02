--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Snowfall over the winter zone: one invisible slab above it with a particle emitter that drops flakes.
local SnowService = {}

function SnowService.Start(park: { ParkFolder: Folder })
	local winter = ParkLayout.ZoneBounds.Winter
	local depth = winter.BoundaryZ - winter.MinZ
	local slab = Instance.new("Part")
	slab.Name = "SnowCloud"
	slab.Size = Vector3.new(ParkLayout.GroundHalfWidth * 2, 1, depth)
	slab.Position = Vector3.new(0, 70, (winter.BoundaryZ + winter.MinZ) / 2)
	slab.Anchored = true
	slab.CanCollide = false
	slab.CanQuery = false
	slab.CanTouch = false
	slab.Transparency = 1
	slab.Parent = park.ParkFolder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	emitter.Size = NumberSequence.new(0.7)
	emitter.Lifetime = NumberRange.new(7, 9)
	emitter.Rate = 220
	emitter.Speed = NumberRange.new(8, 12)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.LightEmission = 0.4
	emitter.Parent = slab
end

return SnowService
