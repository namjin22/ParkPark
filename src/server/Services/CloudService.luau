--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Ambient particles over the Cloud zone: an invisible slab with a soft emitter.
local CloudService = {}

function CloudService.Start(park: { ParkFolder: Folder })
	local zone = ParkLayout.ZoneBounds.Cloud
	local depth = zone.BoundaryZ - zone.MinZ
	local slab = Instance.new("Part")
	slab.Name = "CloudWisps"
	slab.Size = Vector3.new(ParkLayout.GroundHalfWidth * 2, 1, depth)
	slab.Position = Vector3.new(0, 5, (zone.BoundaryZ + zone.MinZ) / 2)
	slab.Anchored = true
	slab.CanCollide = false
	slab.CanQuery = false
	slab.CanTouch = false
	slab.Transparency = 1
	slab.Parent = park.ParkFolder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 232, 255))
	emitter.Size = NumberSequence.new(14)
	emitter.Lifetime = NumberRange.new(8, 12)
	emitter.Rate = 14
	emitter.Speed = NumberRange.new(1, 2)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.LightEmission = 0.3
	emitter.Parent = slab
end

return CloudService
