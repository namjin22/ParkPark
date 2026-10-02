--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Drifting star sparkles over the space zone: one invisible slab near the ground with a slow, glowing emitter.
local SpaceService = {}

function SpaceService.Start(park: { ParkFolder: Folder })
	local space = ParkLayout.ZoneBounds.Space
	local depth = space.BoundaryZ - space.MinZ
	local slab = Instance.new("Part")
	slab.Name = "StarField"
	slab.Size = Vector3.new(ParkLayout.GroundHalfWidth * 2, 1, depth)
	slab.Position = Vector3.new(0, 4, (space.BoundaryZ + space.MinZ) / 2)
	slab.Anchored = true
	slab.CanCollide = false
	slab.CanQuery = false
	slab.CanTouch = false
	slab.Transparency = 1
	slab.Parent = park.ParkFolder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(190, 170, 255), Color3.fromRGB(255, 226, 150))
	emitter.Size = NumberSequence.new(0.9)
	emitter.Lifetime = NumberRange.new(6, 9)
	emitter.Rate = 150
	emitter.Speed = NumberRange.new(2, 4)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.LightEmission = 0.8
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = slab
end

return SpaceService
