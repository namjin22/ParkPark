--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Slow green-gold pollen drifting low over the jungle zone: an invisible slab with a soft, sparse emitter.
local JungleService = {}

function JungleService.Start(park: { ParkFolder: Folder })
	local jungle = ParkLayout.ZoneBounds.Jungle
	local depth = jungle.BoundaryZ - jungle.MinZ
	local slab = Instance.new("Part")
	slab.Name = "JunglePollen"
	slab.Size = Vector3.new(ParkLayout.GroundHalfWidth * 2, 1, depth)
	slab.Position = Vector3.new(0, 6, (jungle.BoundaryZ + jungle.MinZ) / 2)
	slab.Anchored = true
	slab.CanCollide = false
	slab.CanQuery = false
	slab.CanTouch = false
	slab.Transparency = 1
	slab.Parent = park.ParkFolder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(210, 240, 140), Color3.fromRGB(255, 232, 130))
	emitter.Size = NumberSequence.new(0.6)
	emitter.Lifetime = NumberRange.new(7, 10)
	emitter.Rate = 60
	emitter.Speed = NumberRange.new(1, 2)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.LightEmission = 0.6
	emitter.Parent = slab
end

return JungleService
