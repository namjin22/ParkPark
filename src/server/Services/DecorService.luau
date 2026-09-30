--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Scenery that makes the park feel lived in: trees and bushes on the grass, lamp posts and benches along the
-- paths, a plaza fountain, and balloon bunches near the gate. Placement is deterministic (a fixed seed), so
-- every server builds the same park, and it keeps clear of the paths, ride sites, and other props. The
-- authored `Decor*` templates (ParkParkAssets) are cloned when present; until they are imported a simple
-- graybox stand-in is used.
local DecorService = {}

type FindTemplate = (string) -> Model?

type Rect = { number }

local SEED = 20260930
local TREE_COUNT = 78
local BUSH_SCATTER = 44
local BUSH_EDGE = 36
local WORLD_X = 238
local WORLD_MIN_Z = -158
local WORLD_MAX_Z = 108

local FOUNTAIN_POSITION = Vector3.new(58, 0, 64)

-- Ground already used by paths and gathering places: minX, maxX, minZ, maxZ.
local RECTS: { Rect } = {
	{ -10, 10, -58, 108 },
	{ -175, 175, -21, -3 },
	{ -52, -9, -4, 12 },
	{ 9, 64, 8, 24 },
	{ -133, -117, -3, 42 },
	{ 127, 143, -3, 54 },
	{ -24, 24, 18, 36 },
}

local function inRect(x: number, z: number, rect: Rect, margin: number): boolean
	return x >= rect[1] - margin and x <= rect[2] + margin and z >= rect[3] - margin and z <= rect[4] + margin
end

local function nearCircle(x: number, z: number, center: Vector3, radius: number, margin: number): boolean
	local dx, dz = x - center.X, z - center.Z
	return dx * dx + dz * dz < (radius + margin) ^ 2
end

-- Attractions and fixed props, which scenery must stay off.
local function blockedByStructures(x: number, z: number, margin: number): boolean
	for _, site in ParkLayout.Rides do
		if nearCircle(x, z, site.Pivot, site.PlatformRadius, 10 + margin) then
			return true
		end
	end
	for _, spot in { ParkLayout.GeneratorPosition, ParkLayout.JanitorCartPosition, Vector3.new(-32, 0, 52) } do
		if nearCircle(x, z, spot, 6, 6 + margin) then
			return true
		end
	end
	return nearCircle(x, z, FOUNTAIN_POSITION, 6, 5 + margin)
end

local function blocked(x: number, z: number, margin: number): boolean
	if blockedByStructures(x, z, margin) then
		return true
	end
	for _, rect in RECTS do
		if inRect(x, z, rect, margin) then
			return true
		end
	end
	return false
end

-- Stand-ins used until the authored templates exist.
local function grayboxDecor(kind: string): Model
	local model = Instance.new("Model")
	model.Name = kind
	local function part(name: string, size: Vector3, position: Vector3, color: Color3, shape: Enum.PartType?): Part
		local piece = Instance.new("Part")
		piece.Name = name
		piece.Size = size
		piece.Position = position
		piece.Color = color
		piece.Material = Enum.Material.SmoothPlastic
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanQuery = false
		if shape then
			piece.Shape = shape
		end
		piece.Parent = model
		return piece
	end
	-- An unrotated pivot keeps rotated cylinders from tipping the whole model when it is placed.
	local pivot = part("Pivot", Vector3.new(0.2, 0.2, 0.2), Vector3.zero, Color3.new(1, 1, 1), nil)
	pivot.Transparency = 1
	model.PrimaryPart = pivot
	local green = Color3.fromRGB(96, 178, 146)
	local wood = Color3.fromRGB(122, 84, 52)
	if kind == "DecorTree" then
		local trunk = part("Trunk", Vector3.new(2, 2.4, 2), Vector3.new(0, 3, 0), wood, nil)
		trunk.Size = Vector3.new(6, 2.4, 2.4)
		trunk.CFrame = CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.pi / 2)
		trunk.Shape = Enum.PartType.Cylinder
		trunk.CanCollide = true
		part("Canopy", Vector3.new(11, 9, 11), Vector3.new(0, 10, 0), green, Enum.PartType.Ball)
	elseif kind == "DecorBush" then
		part("Bush", Vector3.new(5, 3.4, 4.4), Vector3.new(0, 1.7, 0), green, Enum.PartType.Ball)
	elseif kind == "DecorLamp" then
		local pole = part("Pole", Vector3.new(12, 1, 1), Vector3.new(0, 6, 0), Color3.fromRGB(255, 241, 210), nil)
		pole.CFrame = CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, math.pi / 2)
		pole.Shape = Enum.PartType.Cylinder
		pole.CanCollide = true
		part("Lantern", Vector3.new(2, 2.4, 2), Vector3.new(0, 13, 0), Color3.fromRGB(255, 215, 122), nil)
	elseif kind == "DecorBench" then
		local seat = part("Seat", Vector3.new(5, 0.4, 2), Vector3.new(0, 1.6, 0), wood, nil)
		seat.CanCollide = true
		part("Back", Vector3.new(5, 1.6, 0.3), Vector3.new(0, 2.8, 1), wood, nil)
	elseif kind == "DecorFountain" then
		local basin = part("Basin", Vector3.new(2, 20, 20), Vector3.new(0, 1, 0), Color3.fromRGB(255, 241, 210), nil)
		basin.CFrame = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.pi / 2)
		basin.Shape = Enum.PartType.Cylinder
		basin.CanCollide = true
		part("Water", Vector3.new(1, 3, 3), Vector3.new(0, 4, 0), Color3.fromRGB(150, 210, 230), Enum.PartType.Ball)
	else
		part("Balloon", Vector3.new(3, 3.6, 3), Vector3.new(0, 9, 0), Color3.fromRGB(244, 127, 112), Enum.PartType.Ball)
	end
	return model
end

function DecorService.Start(park: { ParkFolder: Folder }, findTemplate: FindTemplate)
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = park.ParkFolder

	local random = Random.new(SEED)
	local placed: { { position: Vector3, radius: number } } = {}

	local function place(kind: string, position: Vector3, yaw: number, radius: number)
		local template = findTemplate(kind)
		local model = if template then template:Clone() else grayboxDecor(kind)
		model.Name = kind
		model:PivotTo(CFrame.new(position) * CFrame.Angles(0, yaw, 0))
		model.Parent = folder
		table.insert(placed, { position = position, radius = radius })
	end

	local function clear(x: number, z: number, radius: number): boolean
		for _, other in placed do
			local dx, dz = x - other.position.X, z - other.position.Z
			if dx * dx + dz * dz < (radius + other.radius) ^ 2 then
				return false
			end
		end
		return true
	end

	-- Fixed pieces first, so scattered ones keep out of their way.
	place("DecorFountain", FOUNTAIN_POSITION, 0, 12)
	for _, spot in
		{
			Vector3.new(-24, 0, 40),
			Vector3.new(24, 0, 40),
			Vector3.new(-15, 0, 94),
			Vector3.new(15, 0, 94),
			Vector3.new(58, 0, 44),
		}
	do
		place("DecorBalloons", spot, random:NextNumber(0, math.pi * 2), 3)
	end

	-- Lamp posts and benches along the main path (they face inward) and the side path.
	local lampSpots: { Vector3 } = {}
	for z = 100, -50, -24 do
		for _, side in { -1, 1 } do
			table.insert(lampSpots, Vector3.new(side * 13.5, 0, z))
		end
	end
	for x = -165, 165, 30 do
		if math.abs(x) > 16 then
			table.insert(lampSpots, Vector3.new(x, 0, -1))
			table.insert(lampSpots, Vector3.new(x, 0, -23))
		end
	end
	for _, spot in lampSpots do
		if not blockedByStructures(spot.X, spot.Z, 0) and not inRect(spot.X, spot.Z, RECTS[7], 0) then
			place("DecorLamp", spot, 0, 1.5)
		end
	end

	local benchSpots: { { Vector3 } } = {
		{ Vector3.new(-14.5, 0, 74), Vector3.new(1, 0, 0) },
		{ Vector3.new(14.5, 0, 62), Vector3.new(-1, 0, 0) },
		{ Vector3.new(-14.5, 0, 6), Vector3.new(1, 0, 0) },
		{ Vector3.new(14.5, 0, -30), Vector3.new(-1, 0, 0) },
		{ Vector3.new(-14.5, 0, -46), Vector3.new(1, 0, 0) },
		{ Vector3.new(-72, 0, -1.5), Vector3.new(0, 0, -1) },
		{ Vector3.new(72, 0, -22.5), Vector3.new(0, 0, 1) },
		{ Vector3.new(-100, 0, -22.5), Vector3.new(0, 0, 1) },
		{ Vector3.new(100, 0, -1.5), Vector3.new(0, 0, -1) },
		{ Vector3.new(FOUNTAIN_POSITION.X - 11, 0, FOUNTAIN_POSITION.Z), Vector3.new(1, 0, 0) },
		{ Vector3.new(FOUNTAIN_POSITION.X + 11, 0, FOUNTAIN_POSITION.Z), Vector3.new(-1, 0, 0) },
	}
	for _, bench in benchSpots do
		local position, facing = bench[1], bench[2]
		if not blockedByStructures(position.X, position.Z, 0) then
			-- A bench's front is local -Z, so look toward the direction it should face.
			local look = CFrame.lookAt(position, position + facing)
			local _, yaw = look:ToOrientation()
			place("DecorBench", position, yaw, 2.5)
		end
	end

	-- Trees over the grass, well off the paths and rides.
	local trees = 0
	local attempts = 0
	while trees < TREE_COUNT and attempts < 2500 do
		attempts += 1
		local x = random:NextNumber(-WORLD_X, WORLD_X)
		local z = random:NextNumber(WORLD_MIN_Z, WORLD_MAX_Z)
		if not blocked(x, z, 7) and clear(x, z, 8) then
			place("DecorTree", Vector3.new(x, 0, z), random:NextNumber(0, math.pi * 2), 5)
			trees += 1
		end
	end

	-- Bushes: some scattered, some hugging the path edges.
	local bushes = 0
	attempts = 0
	while bushes < BUSH_SCATTER and attempts < 2000 do
		attempts += 1
		local x = random:NextNumber(-WORLD_X, WORLD_X)
		local z = random:NextNumber(WORLD_MIN_Z, WORLD_MAX_Z)
		if not blocked(x, z, 3) and clear(x, z, 3.5) then
			place("DecorBush", Vector3.new(x, 0, z), random:NextNumber(0, math.pi * 2), 2)
			bushes += 1
		end
	end
	bushes = 0
	attempts = 0
	while bushes < BUSH_EDGE and attempts < 2000 do
		attempts += 1
		local x: number
		local z: number
		if random:NextNumber() < 0.55 then
			x = (if random:NextNumber() < 0.5 then -1 else 1) * random:NextNumber(12.5, 15.5)
			z = random:NextNumber(-52, 106)
		else
			x = random:NextNumber(-170, 170)
			z = -12 + (if random:NextNumber() < 0.5 then -1 else 1) * random:NextNumber(10.5, 13.5)
		end
		if not blocked(x, z, -2) and not blockedByStructures(x, z, 0) and clear(x, z, 3) then
			place("DecorBush", Vector3.new(x, 0, z), random:NextNumber(0, math.pi * 2), 1.8)
			bushes += 1
		end
	end
end

return DecorService
