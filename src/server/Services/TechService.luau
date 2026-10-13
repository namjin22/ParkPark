--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Ambient particles over the Tech zone: slow neon motes rising from an invisible slab.
local TechService = {}

function TechService.Start(park: { ParkFolder: Folder })
	local zone = ParkLayout.ZoneBounds.Tech
	local depth = zone.BoundaryZ - zone.MinZ
	local slab = Instance.new("Part")
	slab.Name = "TechMotes"
	slab.Size = Vector3.new(ParkLayout.GroundHalfWidth * 2, 1, depth)
	slab.Position = Vector3.new(0, 2, (zone.BoundaryZ + zone.MinZ) / 2)
	slab.Anchored = true
	slab.CanCollide = false
	slab.CanQuery = false
	slab.CanTouch = false
	slab.Transparency = 1
	slab.Parent = park.ParkFolder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(120, 230, 255), Color3.fromRGB(255, 130, 200))
	emitter.Size = NumberSequence.new(1.6)
	emitter.Lifetime = NumberRange.new(8, 12)
	emitter.Rate = 18
	emitter.Speed = NumberRange.new(2, 4)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.LightEmission = 0.8
	emitter.Transparency = NumberSequence.new(0.5)
	emitter.Parent = slab
end

return TechService
