--!strict

local GameConfig = require(script.Parent:WaitForChild("GameConfig"))

-- Data-driven attractions that need no code of their own beyond ExtraRideService: each is a template model
-- (`ParkParkAssets/<Template>`, or a generated graybox while it is missing) with a `Console` part and a
-- kind-specific mover:
--   Spinner:  `Hub` turns and the `Seat1..N` parts spin on their own axes (like the teacups).
--   Carousel: `Hub` turns and the `Seat1..N` parts bob up and down on their poles.
--   Bounce:   the `Seat1..N` parts hop up and down in turn on a fixed pad.
--   Hidden:   guests walk in and are out of sight for the tour (like the haunted house); `Seat1..N` are markers.
--   Shop:     a counter (`Counter` part) where the head guest is served, like the snack stand.
--   Track:    a `<CarsName>` model with `<CarPrefix>1..N` cars runs a closed loop (TrackService, config keys
--             `<TrackPrefix>Scale`, `<TrackPrefix>CarCount`, ...; the path is the generated `<PathModule>`).
-- The rider's root sits `SeatLift * Scale + RiderHip` above a seat part's centre (Track rides use the shared
-- track offsets). The pivot and the guest queue come from ParkLayout.Rides[key]; `PivotYaw` turns the model.
export type ExtraSpec = {
	Kind: string,
	Template: string,
	Scale: number,
	SeatCount: number,
	SeatLift: number,
	RiderHip: number,
	-- Which way a rider faces relative to the seat part (degrees about Y).
	RiderYaw: number?,
	PivotYaw: number?,
	HubRadius: number?,
	SeatOrbit: number?,
	HubSeconds: number?,
	SpinSeconds: number?,
	BounceHeight: number?,
	BouncePeriod: number?,
	TrackPrefix: string?,
	PathModule: string?,
	CarsName: string?,
	CarPrefix: string?,
}

local ExtraRides: { [string]: ExtraSpec } = {
	Duck = {
		Kind = "Spinner",
		Template = GameConfig.Rides.Duck.ModelName,
		Scale = GameConfig.DuckScale,
		SeatCount = 6,
		SeatLift = 0.33,
		RiderHip = 1.4,
		HubSeconds = 16,
		SpinSeconds = 7,
	},
	Bounce = {
		Kind = "Bounce",
		Template = GameConfig.Rides.Bounce.ModelName,
		Scale = GameConfig.BounceScale,
		SeatCount = 6,
		SeatLift = 0,
		RiderHip = 2.6,
		BounceHeight = 7,
		BouncePeriod = 1.1,
	},
	Bunny = {
		Kind = "Carousel",
		Template = GameConfig.Rides.Bunny.ModelName,
		Scale = GameConfig.BunnyScale,
		SeatCount = 6,
		SeatLift = 0.17,
		RiderHip = 1.4,
		HubSeconds = 14,
		BounceHeight = 2.6,
		BouncePeriod = 2.4,
		HubRadius = 6.8,
		SeatOrbit = 4.4,
	},
	Mine = {
		Kind = "Track",
		Template = GameConfig.Rides.Mine.ModelName,
		Scale = GameConfig.MineScale,
		SeatCount = GameConfig.MineSeatCount,
		SeatLift = 0,
		RiderHip = 0,
		PivotYaw = 180,
		TrackPrefix = "Mine",
		PathModule = "MinePath",
		CarsName = "MineCars",
		CarPrefix = "MineCar",
	},
	Sky = {
		Kind = "Track",
		Template = GameConfig.Rides.Sky.ModelName,
		Scale = GameConfig.SkyScale,
		SeatCount = GameConfig.SkySeatCount,
		SeatLift = 0,
		RiderHip = 0,
		PivotYaw = 180,
		TrackPrefix = "Sky",
		PathModule = "SkyPath",
		CarsName = "SkyCars",
		CarPrefix = "SkyCar",
	},
	IceCream = {
		Kind = "Shop",
		Template = GameConfig.Rides.IceCream.ModelName,
		Scale = GameConfig.ShopScale,
		SeatCount = 1,
		SeatLift = 0,
		RiderHip = 0,
	},
	Pizza = {
		Kind = "Shop",
		Template = GameConfig.Rides.Pizza.ModelName,
		Scale = GameConfig.ShopScale,
		SeatCount = 1,
		SeatLift = 0,
		RiderHip = 0,
	},
	Noodle = {
		Kind = "Shop",
		Template = GameConfig.Rides.Noodle.ModelName,
		Scale = GameConfig.ShopScale,
		SeatCount = 1,
		SeatLift = 0,
		RiderHip = 0,
	},
	Maze = {
		Kind = "Hidden",
		Template = GameConfig.Rides.Maze.ModelName,
		Scale = GameConfig.MazeScale,
		SeatCount = 6,
		SeatLift = 0,
		RiderHip = 0,
	},
}

return ExtraRides
