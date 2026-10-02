--!strict

local GameConfig = require(script.Parent.GameConfig)

-- World layout shared by the builder (paths, ground, ride pivots), the guest routes, and litter.
-- Guests arrive from +Z, walk south through the gate, and reach the carousel on the main path or
-- the teacups and bumper cars on the side path that crosses it.
local ParkLayout = {}

export type RideSite = {
	Pivot: Vector3,
	PlatformRadius: number,
	-- Where the first guest in line stands, and the unit direction the rest of the line extends.
	QueueHead: Vector3,
	QueueDirection: Vector3,
}

ParkLayout.SpawnZ = 78
ParkLayout.EntryZ = 100
ParkLayout.GateZ = 25
ParkLayout.MainPathHalfWidth = 10
ParkLayout.SidePathZ = -12
ParkLayout.SidePathHalfWidth = 9
ParkLayout.SnackZ = 4
ParkLayout.SnackPathHalfWidth = 8
ParkLayout.FerrisZ = 16
-- The power generator beside the path between the spawn and the gate; litter keeps clear of it.
-- The water zone lies beyond the carousel, past a fence across z = ZoneBoundaryZ. Its road (x = ZoneRoadX)
-- branches north off the side path; each ride there has a branch path at ZoneBranchZ[key] leading to its line.
ParkLayout.ZoneBoundaryZ = -168
ParkLayout.ZoneGroundMinZ = -361
ParkLayout.ZoneRoadX = 52
ParkLayout.ZoneRoadHalfWidth = 8
ParkLayout.ZoneBranchZ = {
	Flume = -191,
	Drop = -197,
	Gift = -282,
	Train = -397,
	Duck = -437,
	Bounce = -501,
	Bunny = -521,
	Mine = -683,
	Sky = -656,
	Maze = -801,
	IceCream = -282,
	Pizza = -377,
	Noodle = -811,
	Swan = -282,
	BallPit = -437,
	Rocket = -656,
	Show = -282,
	Penguin = -945,
	Sled = -945,
	Cave = -1060,
	Cocoa = -1060,
} :: { [string]: number }
ParkLayout.ZoneBounds = {
	Water = { BoundaryZ = -168, MinZ = -361 },
	Kids = { BoundaryZ = -361, MinZ = -617 },
	Adventure = { BoundaryZ = -617, MinZ = -927 },
	Winter = { BoundaryZ = -927, MinZ = -1190 },
} :: { [string]: { BoundaryZ: number, MinZ: number } }
ParkLayout.GeneratorPosition = Vector3.new(24, 0, 52)
-- The speed shop stands beside the spawn path.
ParkLayout.SpeedShopPosition = Vector3.new(-26, 0, 72)
-- The repair shop (mechanics) beside the generator and the decor shop opposite the speed shop.
ParkLayout.MechanicShopPosition = Vector3.new(24, 0, 68)
ParkLayout.DecorShopPosition = Vector3.new(26, 0, 90)
-- Plots around the plaza that the decor shop fills one by one.
ParkLayout.DecorPlots = {
	Vector3.new(-48, 0, 50),
	Vector3.new(-48, 0, 70),
	Vector3.new(-48, 0, 90),
	Vector3.new(-72, 0, 60),
	Vector3.new(-72, 0, 80),
	Vector3.new(-72, 0, 98),
	Vector3.new(46, 0, 96),
	Vector3.new(72, 0, 94),
	Vector3.new(96, 0, 72),
	Vector3.new(96, 0, 94),
	Vector3.new(96, 0, 50),
	Vector3.new(46, 0, 50),
} :: { Vector3 }
-- The cleaning cart where janitors are hired, on the other side of the same path.
ParkLayout.JanitorCartPosition = Vector3.new(-24, 0, 52)
ParkLayout.GroundHalfWidth = 260
-- The side path runs this far out to each side, past the outermost ride queues.
ParkLayout.SidePathReach = 175
-- The first park's ground ends exactly where the water zone's ground begins (ZoneBounds.Water.BoundaryZ).
ParkLayout.GroundMinZ = -168
ParkLayout.GroundMaxZ = 115

local CAROUSEL_PIVOT = Vector3.new(0, 0, -95)
local TEACUPS_PIVOT = Vector3.new(-105, 0, -60)
local BUMPER_PIVOT = Vector3.new(105, 0, -60)
-- The snack stand stands at the end of a short spur off the main path, its counter facing +X.
local SNACK_PIVOT = Vector3.new(-50, 0, ParkLayout.SnackZ)
-- The Ferris wheel mirrors it on the other side of the main path, its wheel turning in the YZ plane.
local FERRIS_PIVOT = Vector3.new(66, 0, ParkLayout.FerrisZ)

-- Attractions reached along a short spur off the main path instead of the side path: the spur's z and the
-- x where it meets the main path.
local SPURS: { [string]: { Z: number, InnerX: number } } = {
	Snack = { Z = ParkLayout.SnackZ, InnerX = -8 },
	Ferris = { Z = ParkLayout.FerrisZ, InnerX = 8 },
}

local carouselRadius = GameConfig.CarouselPlatformRadius * GameConfig.CarouselScale
local teacupsRadius = GameConfig.TeacupsPlatformRadius * GameConfig.TeacupsScale
local bumperRadius = GameConfig.BumperPlatformRadius * GameConfig.BumperScale
local swingRadius = GameConfig.SwingPlatformRadius * GameConfig.SwingScale
local pirateRadius = GameConfig.PiratePlatformRadius * GameConfig.PirateScale

ParkLayout.Rides = {
	Carousel = {
		Pivot = CAROUSEL_PIVOT,
		PlatformRadius = carouselRadius,
		QueueHead = Vector3.new(0, 0, CAROUSEL_PIVOT.Z + carouselRadius + 6),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	Teacups = {
		Pivot = TEACUPS_PIVOT,
		PlatformRadius = teacupsRadius,
		QueueHead = Vector3.new(TEACUPS_PIVOT.X, 0, TEACUPS_PIVOT.Z + teacupsRadius + 5),
		QueueDirection = Vector3.new(1, 0, 0),
	},
	Bumper = {
		Pivot = BUMPER_PIVOT,
		PlatformRadius = bumperRadius,
		QueueHead = Vector3.new(BUMPER_PIVOT.X, 0, BUMPER_PIVOT.Z + bumperRadius + 5),
		QueueDirection = Vector3.new(-1, 0, 0),
	},
	-- The swing ride stands at the west end of the side path; its line runs back along the path.
	Swing = {
		Pivot = Vector3.new(-150 - swingRadius - 6, 0, ParkLayout.SidePathZ),
		PlatformRadius = swingRadius,
		QueueHead = Vector3.new(-150, 0, ParkLayout.SidePathZ),
		QueueDirection = Vector3.new(1, 0, 0),
	},
	-- The pirate ship stands at the east end of the side path, mirroring the swing ride.
	Pirate = {
		Pivot = Vector3.new(150 + pirateRadius + 6, 0, ParkLayout.SidePathZ),
		PlatformRadius = pirateRadius,
		QueueHead = Vector3.new(150, 0, ParkLayout.SidePathZ),
		QueueDirection = Vector3.new(-1, 0, 0),
	},
	-- The haunted house stands north of the side path on a branch path at x = -125; its line runs south along
	-- the branch to the side path (guests reach the branch by the ordinary side-path route).
	Haunted = {
		Pivot = Vector3.new(-125, 0, 64),
		PlatformRadius = 26,
		QueueHead = Vector3.new(-125, 0, 34),
		QueueDirection = Vector3.new(0, 0, -1),
	},
	-- The roller coaster stands north of the side path on a branch at x = 135, with its station facing the line.
	Coaster = {
		Pivot = Vector3.new(135, 0, 80),
		PlatformRadius = 42,
		QueueHead = Vector3.new(135, 0, 46),
		QueueDirection = Vector3.new(0, 0, -1),
	},
	-- Zone rides face the road, so the model is turned half a turn and its line runs toward +Z.
	Flume = {
		Pivot = Vector3.new(-2, 0, -231),
		PlatformRadius = 45,
		QueueHead = Vector3.new(-2, 0, -212),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	-- The drop tower stands east of the zone road; its line runs toward +Z to the branch.
	Drop = {
		Pivot = Vector3.new(103, 0, -231),
		PlatformRadius = 20,
		QueueHead = Vector3.new(103, 0, -216),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	-- The gift shop stands at the north end of the zone road, east side; its counter faces +Z like the lines above.
	Gift = {
		Pivot = Vector3.new(110, 0, -307),
		PlatformRadius = 14,
		QueueHead = Vector3.new(110, 0, -301),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	-- The mini train sits west of the zone road in the kids' zone, turned toward the road like the flume.
	Train = {
		Pivot = Vector3.new(-9, 0, -449),
		PlatformRadius = 42,
		QueueHead = Vector3.new(-9, 0, -424),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	-- East of the zone road; every kids' ride faces +Z so its line runs up to a branch off the road.
	Duck = {
		Pivot = Vector3.new(114, 0, -489),
		PlatformRadius = 30,
		QueueHead = Vector3.new(114, 0, -461),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	Bounce = {
		Pivot = Vector3.new(-86, 0, -553),
		PlatformRadius = 30,
		QueueHead = Vector3.new(-86, 0, -523),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	Bunny = {
		Pivot = Vector3.new(114, 0, -575),
		PlatformRadius = 24,
		QueueHead = Vector3.new(114, 0, -547),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	-- The adventure zone: the mine train west of its road, the sky ride east (its cable runs far north of the
	-- station, hence the large radius), and the maze beyond the mine train.
	Mine = {
		Pivot = Vector3.new(-26, 0, -748),
		PlatformRadius = 66,
		QueueHead = Vector3.new(-26, 0, -716),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	Sky = {
		Pivot = Vector3.new(130, 0, -714),
		PlatformRadius = 100,
		QueueHead = Vector3.new(130, 0, -689),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	Maze = {
		Pivot = Vector3.new(-26, 0, -869),
		PlatformRadius = 42,
		QueueHead = Vector3.new(-26, 0, -833),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	-- Shops: the counter faces +Z toward its line.
	IceCream = {
		Pivot = Vector3.new(-10, 0, -307),
		PlatformRadius = 16,
		QueueHead = Vector3.new(-10, 0, -301),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	Pizza = {
		Pivot = Vector3.new(-94, 0, -413),
		PlatformRadius = 16,
		QueueHead = Vector3.new(-94, 0, -405),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	Noodle = {
		Pivot = Vector3.new(90, 0, -850),
		PlatformRadius = 16,
		QueueHead = Vector3.new(90, 0, -840),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	Swan = {
		Pivot = Vector3.new(-70, 0, -319),
		PlatformRadius = 26,
		QueueHead = Vector3.new(-70, 0, -301),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	BallPit = {
		Pivot = Vector3.new(186, 0, -483),
		PlatformRadius = 26,
		QueueHead = Vector3.new(186, 0, -461),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	Rocket = {
		Pivot = Vector3.new(-126, 0, -714),
		PlatformRadius = 26,
		QueueHead = Vector3.new(-126, 0, -685),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	-- The show stage (water zone) and the winter zone's rides; every queue line runs toward +Z to its branch.
	Show = {
		Pivot = Vector3.new(180, 0, -325),
		PlatformRadius = 26,
		QueueHead = Vector3.new(180, 0, -300),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	Penguin = {
		Pivot = Vector3.new(-60, 0, -1000),
		PlatformRadius = 26,
		QueueHead = Vector3.new(-60, 0, -970),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	Sled = {
		Pivot = Vector3.new(150, 0, -1000),
		PlatformRadius = 26,
		QueueHead = Vector3.new(150, 0, -970),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	Cave = {
		Pivot = Vector3.new(-60, 0, -1115),
		PlatformRadius = 34,
		QueueHead = Vector3.new(-60, 0, -1085),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	Cocoa = {
		Pivot = Vector3.new(110, 0, -1085),
		PlatformRadius = 16,
		QueueHead = Vector3.new(110, 0, -1075),
		QueueDirection = Vector3.new(0, 0, 1),
	},
	Ferris = {
		Pivot = FERRIS_PIVOT,
		PlatformRadius = 20,
		QueueHead = Vector3.new(FERRIS_PIVOT.X - 12, 0, ParkLayout.FerrisZ),
		QueueDirection = Vector3.new(-1, 0, 0),
	},
	Snack = {
		Pivot = SNACK_PIVOT,
		PlatformRadius = 10,
		QueueHead = Vector3.new(SNACK_PIVOT.X + 10, 0, ParkLayout.SnackZ),
		QueueDirection = Vector3.new(1, 0, 0),
	},
} :: { [string]: RideSite }

-- Position of the guest standing in line slot `index` (0 is the head of the line).
function ParkLayout.QueueSlot(rideKey: string, index: number, jitter: number): Vector3
	local site = ParkLayout.Rides[rideKey]
	local sideways = Vector3.new(-site.QueueDirection.Z, 0, site.QueueDirection.X)
	return site.QueueHead + site.QueueDirection * (index * GameConfig.QueueSpacing) + sideways * jitter
end

-- Guests move along three legs, always on the paths and kept `lane` studs off the centre line so they do
-- not all stack on one spot: to the crossing where the side path meets the main path, from the crossing to
-- a ride's queue, and from the crossing out to the entry point.

-- Waypoints from a starting point to the crossing. `fromKey` is the ride whose queue the guest is leaving,
-- or nil for a guest who has just arrived at the entry point.
function ParkLayout.ToCrossing(fromKey: string?, from: Vector3, lane: number): { Vector3 }
	local route: { Vector3 } = {}
	if fromKey == nil then
		table.insert(route, Vector3.new(lane, 0, ParkLayout.EntryZ))
		table.insert(route, Vector3.new(lane, 0, ParkLayout.GateZ + 14))
		table.insert(route, Vector3.new(lane, 0, ParkLayout.GateZ - 14))
	elseif ParkLayout.ZoneBranchZ[fromKey] then
		-- Back along the branch to the zone road and down it to the side path.
		local branchZ = ParkLayout.ZoneBranchZ[fromKey]
		table.insert(route, Vector3.new(from.X, 0, branchZ + lane * 0.3))
		table.insert(route, Vector3.new(ParkLayout.ZoneRoadX + lane * 0.6, 0, branchZ + lane * 0.3))
		table.insert(route, Vector3.new(ParkLayout.ZoneRoadX + lane * 0.6, 0, ParkLayout.SidePathZ))
	elseif SPURS[fromKey] then
		-- Back along the spur to the main path; the caller continues from there.
		local spur = SPURS[fromKey]
		table.insert(route, Vector3.new(spur.InnerX, 0, spur.Z + lane * 0.3))
		table.insert(route, Vector3.new(lane, 0, spur.Z))
		return route
	elseif fromKey == "Carousel" then
		table.insert(route, Vector3.new(lane, 0, from.Z))
	else
		table.insert(route, Vector3.new(from.X, 0, ParkLayout.SidePathZ + lane * 0.6))
	end
	table.insert(route, Vector3.new(lane, 0, ParkLayout.SidePathZ))
	return route
end

function ParkLayout.CrossingToRide(rideKey: string, lane: number, slot: Vector3): { Vector3 }
	local route: { Vector3 } = {}
	if rideKey == "Carousel" then
		table.insert(route, Vector3.new(lane, 0, slot.Z))
	else
		table.insert(route, Vector3.new(slot.X, 0, ParkLayout.SidePathZ + lane * 0.6))
	end
	table.insert(route, slot)
	return route
end

-- The full walk from where a guest is (`fromKey` is the line they are leaving, or nil for a new arrival)
-- to the head of another attraction's line. The snack stand sits north of the crossing, so it is reached
-- before the crossing rather than after it.
function ParkLayout.RouteToRide(
	fromKey: string?,
	from: Vector3,
	lane: number,
	rideKey: string,
	slot: Vector3
): { Vector3 }
	local route: { Vector3 } = {}
	local branchZ = ParkLayout.ZoneBranchZ[rideKey]
	if branchZ then
		local fromBranchZ = if fromKey ~= nil then ParkLayout.ZoneBranchZ[fromKey] else nil
		if fromBranchZ then
			-- Both rides are off the zone road: back to the road, along it, and out the other branch.
			local roadX = ParkLayout.ZoneRoadX + lane * 0.6
			table.insert(route, Vector3.new(from.X, 0, fromBranchZ + lane * 0.3))
			table.insert(route, Vector3.new(roadX, 0, fromBranchZ + lane * 0.3))
			table.insert(route, Vector3.new(roadX, 0, branchZ + lane * 0.3))
			table.insert(route, Vector3.new(slot.X, 0, branchZ + lane * 0.3))
			table.insert(route, slot)
			return route
		end
		for _, point in ParkLayout.ToCrossing(fromKey, from, lane) do
			table.insert(route, point)
		end
		if fromKey ~= nil and SPURS[fromKey] then
			table.insert(route, Vector3.new(lane, 0, ParkLayout.SidePathZ))
		end
		table.insert(route, Vector3.new(ParkLayout.ZoneRoadX + lane * 0.6, 0, ParkLayout.SidePathZ))
		table.insert(route, Vector3.new(ParkLayout.ZoneRoadX + lane * 0.6, 0, branchZ + lane * 0.3))
		table.insert(route, Vector3.new(slot.X, 0, branchZ + lane * 0.3))
		table.insert(route, slot)
		return route
	end

	local targetSpur = SPURS[rideKey]
	if targetSpur then
		if fromKey == nil then
			table.insert(route, Vector3.new(lane, 0, ParkLayout.EntryZ))
			table.insert(route, Vector3.new(lane, 0, ParkLayout.GateZ + 14))
			if targetSpur.Z < ParkLayout.GateZ - 14 then
				table.insert(route, Vector3.new(lane, 0, ParkLayout.GateZ - 14))
			end
		else
			for _, point in ParkLayout.ToCrossing(fromKey, from, lane) do
				table.insert(route, point)
			end
		end
		table.insert(route, Vector3.new(lane, 0, targetSpur.Z))
		table.insert(route, Vector3.new(targetSpur.InnerX, 0, targetSpur.Z + lane * 0.3))
		table.insert(route, slot)
		return route
	end

	for _, point in ParkLayout.ToCrossing(fromKey, from, lane) do
		table.insert(route, point)
	end
	if fromKey ~= nil and SPURS[fromKey] then
		table.insert(route, Vector3.new(lane, 0, ParkLayout.SidePathZ))
	end
	for _, point in ParkLayout.CrossingToRide(rideKey, lane, slot) do
		table.insert(route, point)
	end
	return route
end

function ParkLayout.CrossingToExit(lane: number): { Vector3 }
	return {
		Vector3.new(lane, 0, ParkLayout.GateZ - 14),
		Vector3.new(lane, 0, ParkLayout.GateZ + 14),
		Vector3.new(lane, 0, ParkLayout.EntryZ),
	}
end

return ParkLayout
