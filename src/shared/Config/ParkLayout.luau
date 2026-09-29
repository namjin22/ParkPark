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
ParkLayout.GroundHalfWidth = 190
ParkLayout.GroundMinZ = -170
ParkLayout.GroundMaxZ = 115

local CAROUSEL_PIVOT = Vector3.new(0, 0, -95)
local TEACUPS_PIVOT = Vector3.new(-105, 0, -60)
local BUMPER_PIVOT = Vector3.new(105, 0, -60)

local carouselRadius = GameConfig.CarouselPlatformRadius * GameConfig.CarouselScale
local teacupsRadius = GameConfig.TeacupsPlatformRadius * GameConfig.TeacupsScale
local bumperRadius = GameConfig.BumperPlatformRadius * GameConfig.BumperScale

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

function ParkLayout.CrossingToExit(lane: number): { Vector3 }
	return {
		Vector3.new(lane, 0, ParkLayout.GateZ - 14),
		Vector3.new(lane, 0, ParkLayout.GateZ + 14),
		Vector3.new(lane, 0, ParkLayout.EntryZ),
	}
end

return ParkLayout
