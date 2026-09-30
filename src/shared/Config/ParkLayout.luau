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
ParkLayout.GeneratorPosition = Vector3.new(24, 0, 52)
-- The cleaning cart where janitors are hired, on the other side of the same path.
ParkLayout.JanitorCartPosition = Vector3.new(-24, 0, 52)
ParkLayout.GroundHalfWidth = 260
-- The side path runs this far out to each side, past the outermost ride queues.
ParkLayout.SidePathReach = 175
ParkLayout.GroundMinZ = -170
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
