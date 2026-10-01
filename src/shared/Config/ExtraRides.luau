--!strict

local GameConfig = require(script.Parent:WaitForChild("GameConfig"))

-- Data-driven attractions that need no code of their own beyond ExtraRideService: each is a template model
-- (`ParkParkAssets/<Template>`, or a generated graybox while it is missing) with a `Console` part, `Seat1..N`
-- parts that carry the guests, and a kind-specific mover:
--   Spinner: a `Hub` part turns and every seat part spins on its own axis (like the teacups).
--   Bounce:  the seat parts hop up and down in turn on a fixed pad.
-- The rider's root sits `SeatLift * Scale + RiderHip` above the seat part's centre. The pivot and the guest
-- queue come from ParkLayout.Rides[key].
export type ExtraSpec = {
	Kind: string,
	Template: string,
	Scale: number,
	SeatCount: number,
	SeatLift: number,
	RiderHip: number,
	HubSeconds: number?,
	SpinSeconds: number?,
	BounceHeight: number?,
	BouncePeriod: number?,
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
}

return ExtraRides
