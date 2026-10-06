--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Ambient particles over the Desert zone: an invisible slab with a soft emitter.
local DesertService = {}

function DesertService.Start(park: { ParkFolder: Folder })
	local zone = ParkLayout.ZoneBounds.Desert
	local depth = zone.BoundaryZ - zone.MinZ
	local slab = Instance.new("Part")
	slab.Name = "SandDust"
	slab.Size = Vector3.new(ParkLayout.GroundHalfWidth * 2, 1, depth)
	slab.Position = Vector3.new(0, 4, (zone.BoundaryZ + zone.MinZ) / 2)
	slab.Anchored = true
	slab.CanCollide = false
	slab.CanQuery = false
	slab.CanTouch = false
	slab.Transparency = 1
	slab.Parent = park.ParkFolder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(235, 205, 150), Color3.fromRGB(250, 230, 190))
	emitter.Size = NumberSequence.new(9)
	emitter.Lifetime = NumberRange.new(8, 12)
	emitter.Rate = 40
	emitter.Speed = NumberRange.new(3, 5)
	emitter.EmissionDirection = Enum.NormalId.Right
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.LightEmission = 0.1
	emitter.Parent = slab
end

return DesertService
