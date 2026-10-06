--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Light sea mist over the pirate cove: an invisible slab near the ground with a slow, soft emitter.
local CoveService = {}

function CoveService.Start(park: { ParkFolder: Folder })
	local cove = ParkLayout.ZoneBounds.Cove
	local depth = cove.BoundaryZ - cove.MinZ
	local slab = Instance.new("Part")
	slab.Name = "SeaMist"
	slab.Size = Vector3.new(ParkLayout.GroundHalfWidth * 2, 1, depth)
	slab.Position = Vector3.new(0, 3, (cove.BoundaryZ + cove.MinZ) / 2)
	slab.Anchored = true
	slab.CanCollide = false
	slab.CanQuery = false
	slab.CanTouch = false
	slab.Transparency = 1
	slab.Parent = park.ParkFolder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(205, 225, 228))
	emitter.Size = NumberSequence.new(14)
	emitter.Lifetime = NumberRange.new(9, 13)
	emitter.Rate = 5
	emitter.Speed = NumberRange.new(1, 2)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.88),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = slab
end

return CoveService
