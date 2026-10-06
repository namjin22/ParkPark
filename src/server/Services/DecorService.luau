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
	{ 44, 60, -170, -21 },
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
	for _, spot in
		{
			ParkLayout.GeneratorPosition,
			ParkLayout.JanitorCartPosition,
			ParkLayout.SpeedShopPosition,
			ParkLayout.MechanicShopPosition,
			ParkLayout.DecorShopPosition,
			ParkLayout.DeliveryDeskPosition,
			Vector3.new(-32, 0, 52),
		}
	do
		if nearCircle(x, z, spot, 6, 6 + margin) then
			return true
		end
	end
	for _, plot in ParkLayout.DecorPlots do
		if nearCircle(x, z, plot, 4, 5 + margin) then
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
	elseif kind == "DecorPalm" then
		local trunk = part("Trunk", Vector3.new(9, 1.6, 1.6), Vector3.new(0, 4.5, 0), wood, nil)
		trunk.CFrame = CFrame.new(0, 4.5, 0) * CFrame.Angles(0, 0, math.pi / 2)
		trunk.Shape = Enum.PartType.Cylinder
		trunk.CanCollide = true
		part("Fronds", Vector3.new(11, 2.4, 11), Vector3.new(0, 9.4, 0), green, Enum.PartType.Ball)
	elseif kind == "DecorUmbrella" then
		part("Pole", Vector3.new(0.4, 10, 0.4), Vector3.new(0, 5, 0), wood, nil).CanCollide = true
		local cover = part("Cover", Vector3.new(0.6, 11, 11), Vector3.new(0, 10, 0), Color3.fromRGB(244, 127, 112), nil)
		cover.CFrame = CFrame.new(0, 10, 0) * CFrame.Angles(0, 0, math.pi / 2)
		cover.Shape = Enum.PartType.Cylinder
	elseif kind == "DecorPond" then
		local water =
			part("Water", Vector3.new(0.6, 30, 30), Vector3.new(0, 0.3, 0), Color3.fromRGB(150, 210, 230), nil)
		water.CFrame = CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2)
		water.Shape = Enum.PartType.Cylinder
		water.CanCollide = true
	elseif kind == "DecorPine" then
		part("Trunk", Vector3.new(1.2, 5, 1.2), Vector3.new(0, 2.5, 0), wood, nil).CanCollide = true
		part("Crown", Vector3.new(7, 12, 7), Vector3.new(0, 10, 0), green, Enum.PartType.Ball)
	elseif kind == "DecorRock" then
		local boulder = part(
			"Boulder",
			Vector3.new(7, 5, 6),
			Vector3.new(0, 2.5, 0),
			Color3.fromRGB(150, 142, 130),
			Enum.PartType.Ball
		)
		boulder.CanCollide = true
	elseif kind == "DecorBarrels" then
		part("Barrel", Vector3.new(4, 3, 4), Vector3.new(0, 1.5, 0), wood, Enum.PartType.Cylinder).CanCollide = true
	elseif kind == "DecorCannon" then
		part("Cannon", Vector3.new(2.4, 2.2, 5), Vector3.new(0, 1.4, 0), Color3.fromRGB(70, 74, 80), nil).CanCollide =
			true
	elseif kind == "DecorSandcastle" then
		part("Castle", Vector3.new(8, 6, 8), Vector3.new(0, 3, 0), Color3.fromRGB(235, 200, 120), nil).CanCollide = true
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

	-- Plants and rocks vary a lot from piece to piece; built things (lamps, benches, fountains) only a little, so
	-- the park looks laid out by hand rather than stamped from one mould.
	local NATURAL = {
		DecorTree = true,
		DecorBush = true,
		DecorPalm = true,
		DecorPine = true,
		DecorRock = true,
		DecorCrystal = true,
		DecorSandcastle = true,
		DecorFlowers = true,
		DecorBarrels = true,
	}
	local function place(kind: string, position: Vector3, yaw: number, radius: number)
		local template = findTemplate(kind)
		local model = if template then template:Clone() else grayboxDecor(kind)
		model.Name = kind
		local natural = NATURAL[kind] == true
		local sizeJitter = if natural then random:NextNumber(0.86, 1.16) else random:NextNumber(0.97, 1.03)
		if sizeJitter ~= 1 then
			model:ScaleTo(model:GetScale() * sizeJitter)
		end
		local lean = if natural then random:NextNumber(-0.045, 0.045) else 0
		local lift = if natural then random:NextNumber(-0.04, 0.04) else 0
		local wobble = if natural then 0 else random:NextNumber(-0.08, 0.08)
		local nudge = if natural
			then Vector3.zero
			else Vector3.new(random:NextNumber(-0.7, 0.7), 0, random:NextNumber(-0.7, 0.7))
		model:PivotTo(CFrame.new(position + nudge) * CFrame.Angles(lean, yaw + wobble, lift))
		-- A touch of shade difference so no two trees or bushes are the same green.
		if natural then
			local shade = random:NextNumber(0, 0.09)
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency < 1 then
					part.Color = part.Color:Lerp(Color3.new(0, 0, 0), shade)
				end
			end
		end
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
		if not blocked(spot.X, spot.Z, 0) then
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
		{ Vector3.new(FOUNTAIN_POSITION.X - 14, 0, FOUNTAIN_POSITION.Z), Vector3.new(1, 0, 0) },
		{ Vector3.new(FOUNTAIN_POSITION.X + 14, 0, FOUNTAIN_POSITION.Z), Vector3.new(-1, 0, 0) },
	}
	for _, bench in benchSpots do
		local position, facing = bench[1], bench[2]
		if not blocked(position.X, position.Z, 0) then
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

	-- Little flower patches in the meadow and along the path edges, in a few sizes.
	local patches = 0
	attempts = 0
	while patches < 46 and attempts < 2500 do
		attempts += 1
		local x
		local z = random:NextNumber(WORLD_MIN_Z + 20, 104)
		if random:NextNumber() < 0.5 then
			x = (if random:NextNumber() < 0.5 then -1 else 1) * random:NextNumber(12, 24)
		else
			x = random:NextNumber(-WORLD_X, WORLD_X)
		end
		if not blocked(x, z, 3) and clear(x, z, 3) then
			place("DecorFlowers", Vector3.new(x, 0, z), random:NextNumber(0, math.pi * 2), 2)
			patches += 1
		end
	end

	-- The water zone beyond the fence: ponds, palms, beach umbrellas, sandcastles, and lamps along its road.
	local roadX = ParkLayout.ZoneRoadX
	local roadHalf = ParkLayout.ZoneRoadHalfWidth
	local zoneRects: { Rect } =
		{ { roadX - roadHalf, roadX + roadHalf, ParkLayout.ZoneGroundMinZ, ParkLayout.ZoneBoundaryZ } }
	for key, branchZ in ParkLayout.ZoneBranchZ do
		local site = ParkLayout.Rides[key]
		local lineX = site.QueueHead.X
		table.insert(zoneRects, { math.min(lineX, roadX) - 6, math.max(lineX, roadX) + 6, branchZ - 6, branchZ + 6 })
		table.insert(
			zoneRects,
			{ lineX - 6, lineX + 6, math.min(site.QueueHead.Z - 4, branchZ), math.max(site.QueueHead.Z, branchZ + 6) }
		)
	end
	local kids = ParkLayout.ZoneBounds.Kids
	table.insert(zoneRects, { roadX - roadHalf, roadX + roadHalf, kids.MinZ, kids.BoundaryZ })
	local winter = ParkLayout.ZoneBounds.Winter
	table.insert(zoneRects, { roadX - roadHalf, roadX + roadHalf, winter.MinZ, winter.BoundaryZ })
	local cove = ParkLayout.ZoneBounds.Cove
	table.insert(zoneRects, { roadX - roadHalf, roadX + roadHalf, cove.MinZ, cove.BoundaryZ })
	local space = ParkLayout.ZoneBounds.Space
	table.insert(zoneRects, { roadX - roadHalf, roadX + roadHalf, space.MinZ, space.BoundaryZ })
	local adventure = ParkLayout.ZoneBounds.Adventure
	table.insert(zoneRects, { roadX - roadHalf, roadX + roadHalf, adventure.MinZ, adventure.BoundaryZ })
	local function zoneBlocked(x: number, z: number, margin: number): boolean
		if blockedByStructures(x, z, margin) then
			return true
		end
		for _, rect in zoneRects do
			if inRect(x, z, rect, margin) then
				return true
			end
		end
		return false
	end
	local function zoneRandom(): (number, number)
		return random:NextNumber(-WORLD_X, WORLD_X),
			random:NextNumber(ParkLayout.ZoneGroundMinZ + 6, ParkLayout.ZoneBoundaryZ - 8)
	end

	local ponds: { Vector3 } = {}
	for _, spot in
		{ Vector3.new(-150, 0, -235), Vector3.new(190, 0, -270), Vector3.new(-150, 0, -340), Vector3.new(60, 0, -340) }
	do
		if not zoneBlocked(spot.X, spot.Z, 12) then
			place("DecorPond", spot, random:NextNumber(0, math.pi * 2), 11)
			table.insert(ponds, spot)
		end
	end
	local zoneProps: { { kind: string, count: number, margin: number, radius: number } } = {
		{ kind = "DecorPalm", count = 70, margin = 7, radius = 5 },
		{ kind = "DecorSandcastle", count = 6, margin = 6, radius = 4.5 },
	}
	for _, prop in zoneProps do
		local made = 0
		local tries = 0
		while made < prop.count and tries < 3000 do
			tries += 1
			local x, z = zoneRandom()
			if not zoneBlocked(x, z, prop.margin) and clear(x, z, prop.radius) then
				place(prop.kind, Vector3.new(x, 0, z), random:NextNumber(0, math.pi * 2), prop.radius)
				made += 1
			end
		end
	end
	-- Umbrellas gather around the ponds, with a few scattered beside the road.
	for index = 1, 14 do
		local made = false
		for _ = 1, 40 do
			local x, z
			if index <= 10 and #ponds > 0 then
				local pond = ponds[(index - 1) % #ponds + 1]
				local angle = random:NextNumber(0, math.pi * 2)
				x, z =
					pond.X + math.cos(angle) * random:NextNumber(15, 22),
					pond.Z + math.sin(angle) * random:NextNumber(15, 22)
			else
				x, z = zoneRandom()
			end
			if not zoneBlocked(x, z, 5) and clear(x, z, 5) then
				place("DecorUmbrella", Vector3.new(x, 0, z), random:NextNumber(0, math.pi * 2), 4.5)
				made = true
				break
			end
		end
		if not made then
			break
		end
	end
	for z = -184, -350, -24 do
		for _, side in { -1, 1 } do
			local spot = Vector3.new(roadX + side * (roadHalf + 5.5), 0, z)
			if not zoneBlocked(spot.X, spot.Z, 0) and clear(spot.X, spot.Z, 1.5) then
				place("DecorLamp", spot, 0, 1.5)
			end
		end
	end
	for index, z in { -200, -240, -280, -330 } do
		local side = if index % 2 == 0 then 1 else -1
		local position = Vector3.new(roadX + side * (roadHalf + 3), 0, z)
		if not zoneBlocked(position.X, position.Z, 0) then
			local _, yaw = CFrame.lookAt(position, position + Vector3.new(-side, 0, 0)):ToOrientation()
			place("DecorBench", position, yaw, 2.5)
		end
	end
	for _, spot in { Vector3.new(28, 0, -182), Vector3.new(76, 0, -182) } do
		place("DecorBalloons", spot, random:NextNumber(0, math.pi * 2), 3)
	end

	-- The kids' zone: round green trees and bushes, balloon bunches, and lamps and benches along its road.
	local kidsProps: { { kind: string, count: number, margin: number, radius: number } } = {
		{ kind = "DecorTree", count = 40, margin = 7, radius = 5 },
		{ kind = "DecorBush", count = 60, margin = 4, radius = 2 },
		{ kind = "DecorBalloons", count = 14, margin = 5, radius = 3 },
	}
	for _, prop in kidsProps do
		local made = 0
		local tries = 0
		while made < prop.count and tries < 3000 do
			tries += 1
			local x = random:NextNumber(-WORLD_X, WORLD_X)
			local z = random:NextNumber(kids.MinZ + 6, kids.BoundaryZ - 8)
			if not zoneBlocked(x, z, prop.margin) and clear(x, z, prop.radius) then
				place(prop.kind, Vector3.new(x, 0, z), random:NextNumber(0, math.pi * 2), prop.radius)
				made += 1
			end
		end
	end
	for z = kids.BoundaryZ - 16, kids.MinZ + 12, -24 do
		for _, side in { -1, 1 } do
			local spot = Vector3.new(roadX + side * (roadHalf + 5.5), 0, z)
			if not zoneBlocked(spot.X, spot.Z, 0) and clear(spot.X, spot.Z, 1.5) then
				place("DecorLamp", spot, 0, 1.5)
			end
		end
	end
	for index, z in { -390, -440, -500, -560 } do
		local side = if index % 2 == 0 then 1 else -1
		local position = Vector3.new(roadX + side * (roadHalf + 3), 0, z)
		if not zoneBlocked(position.X, position.Z, 0) then
			local _, yaw = CFrame.lookAt(position, position + Vector3.new(-side, 0, 0)):ToOrientation()
			place("DecorBench", position, yaw, 2.5)
		end
	end

	-- The adventure zone: pines, boulders, a few bushes, and lamps and benches along its road.
	local adventureProps: { { kind: string, count: number, margin: number, radius: number } } = {
		{ kind = "DecorPine", count = 70, margin = 7, radius = 4.5 },
		{ kind = "DecorRock", count = 40, margin = 6, radius = 4 },
		{ kind = "DecorBush", count = 30, margin = 4, radius = 2 },
	}
	for _, prop in adventureProps do
		local made = 0
		local tries = 0
		while made < prop.count and tries < 3000 do
			tries += 1
			local x = random:NextNumber(-WORLD_X, WORLD_X)
			local z = random:NextNumber(adventure.MinZ + 6, adventure.BoundaryZ - 8)
			if not zoneBlocked(x, z, prop.margin) and clear(x, z, prop.radius) then
				place(prop.kind, Vector3.new(x, 0, z), random:NextNumber(0, math.pi * 2), prop.radius)
				made += 1
			end
		end
	end
	for z = adventure.BoundaryZ - 16, adventure.MinZ + 12, -24 do
		for _, side in { -1, 1 } do
			local spot = Vector3.new(roadX + side * (roadHalf + 5.5), 0, z)
			if not zoneBlocked(spot.X, spot.Z, 0) and clear(spot.X, spot.Z, 1.5) then
				place("DecorLamp", spot, 0, 1.5)
			end
		end
	end
	for index, z in { -640, -700, -770, -850 } do
		local side = if index % 2 == 0 then 1 else -1
		local position = Vector3.new(roadX + side * (roadHalf + 3), 0, z)
		if not zoneBlocked(position.X, position.Z, 0) then
			local _, yaw = CFrame.lookAt(position, position + Vector3.new(-side, 0, 0)):ToOrientation()
			place("DecorBench", position, yaw, 2.5)
		end
	end

	-- The winter zone: snowy pines and boulders, with lamps and benches along its road.
	local winterProps: { { kind: string, count: number, margin: number, radius: number } } = {
		{ kind = "DecorPine", count = 45, margin = 7, radius = 4.5 },
		{ kind = "DecorRock", count = 25, margin = 6, radius = 4 },
		{ kind = "DecorBush", count = 12, margin = 4, radius = 2 },
	}
	for _, prop in winterProps do
		local made = 0
		local tries = 0
		while made < prop.count and tries < 3000 do
			tries += 1
			local x = random:NextNumber(-WORLD_X, WORLD_X)
			local z = random:NextNumber(winter.MinZ + 6, winter.BoundaryZ - 8)
			if not zoneBlocked(x, z, prop.margin) and clear(x, z, prop.radius) then
				place(prop.kind, Vector3.new(x, 0, z), random:NextNumber(0, math.pi * 2), prop.radius)
				made += 1
			end
		end
	end
	for z = winter.BoundaryZ - 16, winter.MinZ + 12, -24 do
		for _, side in { -1, 1 } do
			local spot = Vector3.new(roadX + side * (roadHalf + 5.5), 0, z)
			if not zoneBlocked(spot.X, spot.Z, 0) and clear(spot.X, spot.Z, 1.5) then
				place("DecorLamp", spot, 0, 1.5)
			end
		end
	end

	-- The pirate cove: palms, cannons, barrels, rocks and bushes, with lamps along its road.
	local coveProps: { { kind: string, count: number, margin: number, radius: number } } = {
		{ kind = "DecorPalm", count = 26, margin = 7, radius = 5 },
		{ kind = "DecorCannon", count = 10, margin = 6, radius = 3 },
		{ kind = "DecorBarrels", count = 14, margin = 6, radius = 3 },
		{ kind = "DecorRock", count = 20, margin = 6, radius = 4 },
		{ kind = "DecorBush", count = 8, margin = 4, radius = 2 },
	}
	for _, prop in coveProps do
		local made = 0
		local tries = 0
		while made < prop.count and tries < 3000 do
			tries += 1
			local x = random:NextNumber(-WORLD_X, WORLD_X)
			local z = random:NextNumber(cove.MinZ + 6, cove.BoundaryZ - 8)
			if not zoneBlocked(x, z, prop.margin) and clear(x, z, prop.radius) then
				place(prop.kind, Vector3.new(x, 0, z), random:NextNumber(0, math.pi * 2), prop.radius)
				made += 1
			end
		end
	end
	for z = cove.BoundaryZ - 16, cove.MinZ + 12, -24 do
		for _, side in { -1, 1 } do
			local spot = Vector3.new(roadX + side * (roadHalf + 5.5), 0, z)
			if not zoneBlocked(spot.X, spot.Z, 0) and clear(spot.X, spot.Z, 1.5) then
				place("DecorLamp", spot, 0, 1.5)
			end
		end
	end

	-- The space zone: crystals, planets and boulders, with lamps along its road.
	local spaceProps: { { kind: string, count: number, margin: number, radius: number } } = {
		{ kind = "DecorCrystal", count = 45, margin = 6, radius = 3 },
		{ kind = "DecorPlanet", count = 10, margin = 6, radius = 3 },
		{ kind = "DecorRock", count = 18, margin = 6, radius = 4 },
	}
	for _, prop in spaceProps do
		local made = 0
		local tries = 0
		while made < prop.count and tries < 3000 do
			tries += 1
			local x = random:NextNumber(-WORLD_X, WORLD_X)
			local z = random:NextNumber(space.MinZ + 6, space.BoundaryZ - 8)
			if not zoneBlocked(x, z, prop.margin) and clear(x, z, prop.radius) then
				place(prop.kind, Vector3.new(x, 0, z), random:NextNumber(0, math.pi * 2), prop.radius)
				made += 1
			end
		end
	end
	for z = space.BoundaryZ - 16, space.MinZ + 12, -24 do
		for _, side in { -1, 1 } do
			local spot = Vector3.new(roadX + side * (roadHalf + 5.5), 0, z)
			if not zoneBlocked(spot.X, spot.Z, 0) and clear(spot.X, spot.Z, 1.5) then
				place("DecorLamp", spot, 0, 1.5)
			end
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
