--!strict

export type RideEconomy = {
	DisplayName: string,
	-- The ride's model in the park folder and the console players manage it from.
	ModelName: string,
	ConsoleName: string,
	-- 0 means the ride starts unlocked (only the first ride).
	UnlockCost: number,
	RepairCost: number,
	BaseFare: number,
	-- Extra coins per guest for each income level.
	IncomePerLevel: number,
	-- Cost of buying income level 1, 2, ... and staff level 1, 2, ...
	IncomeCosts: { number },
	StaffCosts: { number },
	-- A shop serves guests at a counter instead of seating them on a moving ride.
	IsShop: boolean?,
	-- The zone this attraction belongs to ("Water"): it can be unlocked only once that zone has been opened.
	Zone: string?,
	-- How long a guest stays aboard; rides without it use GuestRideSeconds.
	RideSeconds: number?,
	-- The attraction that must be repaired before this one can be unlocked (the chain runs in this order).
	Requires: string?,
}

return {
	-- Economy: trash earns coins, repairs and upgrades spend them, and guest rides pay them back.
	StartingCoins = 0,
	CurrencyDisplayName = "코인",
	EntranceCleanupReward = 30,
	LitterReward = 3,
	-- Litter keeps appearing near the paths once the entrance has been cleaned.
	LitterSpawnSeconds = 14,
	LitterMax = 14,

	-- Every ride (and the entrance) is sized around the carousel. These scales must match the ones in
	-- tools/build_parkpark_templates.py, and Roblox scales a mesh by Size / InitialSize.
	-- The arch is stretched wide for the path but kept low, so it does not tower over the park.
	EntranceScale = 2.4,
	EntranceHeightScale = 1.6,
	DebrisScale = 2.5,
	LitterScale = 1.6,
	CarouselScale = 3.2,
	TeacupsScale = 4.2,
	BumperScale = 3.7,
	BumperCarScale = 3.2,
	ConsoleScale = 3,
	SnackScale = 3,
	FerrisScale = 2.6,
	SwingScale = 3,
	PirateScale = 3,
	HauntedScale = 3.2,
	CoasterScale = 3,
	FlumeScale = 2.6,
	TreeScale = 1.9,
	BushScale = 1.7,
	LampScale = 2,
	BenchScale = 1.9,
	FountainScale = 2.6,
	BalloonScale = 2,

	Rides = {
		Carousel = {
			DisplayName = "회전목마",
			ModelName = "BrokenCarousel",
			ConsoleName = "RepairConsole",
			UnlockCost = 0,
			RepairCost = 25,
			BaseFare = 5,
			IncomePerLevel = 3,
			IncomeCosts = { 40, 90, 160, 260 },
			StaffCosts = { 70, 150, 260 },
		},
		Teacups = {
			DisplayName = "찻잔 라이드",
			ModelName = "TeacupsRide",
			ConsoleName = "TeacupsConsole",
			UnlockCost = 60,
			RepairCost = 35,
			BaseFare = 8,
			Requires = "Carousel",
			IncomePerLevel = 4,
			IncomeCosts = { 60, 130, 230, 360 },
			StaffCosts = { 100, 200, 340 },
		},
		Bumper = {
			DisplayName = "범퍼카",
			ModelName = "BumperCarsRide",
			ConsoleName = "BumperConsole",
			UnlockCost = 120,
			RepairCost = 60,
			BaseFare = 12,
			Requires = "Snack",
			IncomePerLevel = 6,
			IncomeCosts = { 90, 190, 320, 500 },
			StaffCosts = { 140, 280, 450 },
		},
		Snack = {
			DisplayName = "간식 판매대",
			ModelName = "SnackStand",
			ConsoleName = "SnackConsole",
			UnlockCost = 40,
			RepairCost = 30,
			BaseFare = 4,
			Requires = "Teacups",
			IncomePerLevel = 2,
			IncomeCosts = { 30, 70, 130, 220 },
			StaffCosts = { 60, 120, 220 },
			IsShop = true,
		},
		Ferris = {
			DisplayName = "관람차",
			ModelName = "FerrisWheelRide",
			ConsoleName = "FerrisConsole",
			UnlockCost = 200,
			RepairCost = 100,
			BaseFare = 20,
			Requires = "Bumper",
			IncomePerLevel = 8,
			IncomeCosts = { 150, 300, 520, 800 },
			StaffCosts = { 220, 420, 700 },
			RideSeconds = 40,
		},
		Swing = {
			DisplayName = "회전 그네",
			ModelName = "SwingRide",
			ConsoleName = "SwingConsole",
			UnlockCost = 300,
			RepairCost = 150,
			BaseFare = 28,
			Requires = "Ferris",
			IncomePerLevel = 10,
			IncomeCosts = { 200, 400, 700, 1100 },
			StaffCosts = { 300, 560, 900 },
			RideSeconds = 30,
		},
		Pirate = {
			DisplayName = "해적선",
			ModelName = "PirateRide",
			ConsoleName = "PirateConsole",
			UnlockCost = 450,
			RepairCost = 220,
			BaseFare = 40,
			Requires = "Swing",
			IncomePerLevel = 14,
			IncomeCosts = { 300, 600, 1000, 1600 },
			StaffCosts = { 450, 800, 1300 },
			RideSeconds = 30,
		},
		Haunted = {
			DisplayName = "유령의 집",
			ModelName = "HauntedHouse",
			ConsoleName = "HauntedConsole",
			UnlockCost = 650,
			RepairCost = 300,
			BaseFare = 55,
			Requires = "Pirate",
			IncomePerLevel = 18,
			IncomeCosts = { 400, 800, 1300, 2000 },
			StaffCosts = { 600, 1000, 1600 },
			RideSeconds = 20,
		},
		Coaster = {
			DisplayName = "롤러코스터",
			ModelName = "CoasterRide",
			ConsoleName = "CoasterConsole",
			UnlockCost = 900,
			RepairCost = 400,
			BaseFare = 75,
			Requires = "Haunted",
			IncomePerLevel = 25,
			IncomeCosts = { 600, 1200, 2000, 3200 },
			StaffCosts = { 900, 1500, 2400 },
			RideSeconds = 90,
		},
		Flume = {
			DisplayName = "통나무 급류",
			ModelName = "FlumeRide",
			ConsoleName = "FlumeConsole",
			UnlockCost = 1300,
			RepairCost = 600,
			BaseFare = 95,
			Requires = "Coaster",
			Zone = "Water",
			IncomePerLevel = 30,
			IncomeCosts = { 800, 1500, 2500, 4000 },
			StaffCosts = { 1100, 1800, 2900 },
			RideSeconds = 90,
		},
	} :: { [string]: RideEconomy },
	-- The order attractions unlock in (each needs the one before it repaired).
	RideChain = { "Carousel", "Teacups", "Snack", "Bumper", "Ferris", "Swing", "Pirate", "Haunted", "Coaster", "Flume" },
	-- Zones beyond the first: what opening each costs (paid at its gate once the park's last attraction of the
	-- previous zone is repaired) and how it is named.
	ZoneCosts = { Water = 2500 } :: { [string]: number },
	ZoneNames = { Water = "물 구역" } :: { [string]: string },
	-- Seconds between automatic boardings for staff level 1, 2, 3 (0 staff means players accept guests).
	StaffIntervals = { 10, 6, 3 },

	-- Carousel geometry (unscaled OBJ units from ParkParkCarouselRotor.obj).
	CarouselRotationSeconds = 16,
	CarouselSeatCount = 8,
	CarouselPlatformRadius = 12,

	-- Teacups: a rotating hub carries six cups, and every cup also spins on its own turntable.
	-- Cup numbers are unscaled OBJ units from ParkParkTeacupsHub.obj and ParkParkTeacup.obj.
	TeacupsRotationSeconds = 14,
	TeacupsPlatformRadius = 9.2,
	TeacupCupCount = 6,
	TeacupRingRadius = 6,
	TeacupCupBaseHeight = 1.42,
	TeacupCupCenterHeight = 0.66,
	TeacupCupFloorHeight = 0.46,
	TeacupCupSpinSeconds = 6,
	-- Studs from the cup floor to the guest's root part: the guest stands waist-deep in the cup.
	TeacupStandHeight = 3,
	-- Legacy single-mesh rotor, used only while the template still has no separate cups.
	TeacupsSeatCount = 6,
	TeacupsSeatRadius = 6,
	TeacupsSeatHeight = 1.28,
	TeacupsRotorCenterHeight = 4.72,
	TeacupsRiderHip = 1.05,

	-- Bumper cars: the rink uses BumperScale, the cars use BumperCarScale, and the cars roam the rink.
	BumperSeatCount = 8,
	BumperPlatformRadius = 10.42,
	BumperArenaRadius = 9.5,
	BumperCarRadius = 1.4,
	BumperCarSpeed = 14,
	BumperCarCenterHeight = 2.775,
	BumperSeatHeight = 1.29,
	BumperSeatZ = 0.5,
	BumperRiderHip = 1.05,

	-- Ferris wheel (unscaled OBJ units from ParkParkFerrisWheel/Base/Cabin.obj). Cabins hang from the rim at
	-- FerrisRadius, and a cabin at the bottom is the one guests board. A rider sits on the bench (seat top
	-- FerrisSeatHeight), measured from the cabin's hanger point; the cabin mesh's bounding-box center is at
	-- FerrisCabinCenterHeight, which is where the cabin part's position sits.
	FerrisRotationSeconds = 40,
	FerrisCabinCount = 8,
	FerrisRadius = 6,
	FerrisHubHeight = 9.2,
	FerrisCabinCenterHeight = -1.135,
	FerrisSeatHeight = -2.0,
	FerrisRiderHip = 1.25,
	-- A cabin can be boarded while it is within this fraction of the wheel radius above its lowest point.
	FerrisBoardingWindow = 0.15,

	-- Swing ride (unscaled OBJ units from ParkParkSwingBase/Crown/Seat.obj). The crown turns on top of the
	-- tower, and its speed rises and falls over SwingCycleSeconds; the faster it goes, the further the chairs
	-- swing out (up to SwingMaxAngle degrees). SwingSeatCenter* is the seat mesh's bounding-box centre
	-- relative to its anchor (the OBJ origin), and SwingSeatTop is the height of the bench above the anchor.
	SwingSeatCount = 8,
	SwingTowerHeight = 8,
	SwingAnchorRadius = 4.6,
	SwingAnchorY = -0.4,
	SwingPlatformRadius = 8,
	SwingRotationSeconds = 4,
	SwingCycleSeconds = 20,
	SwingMaxAngle = 42,
	SwingSeatCenterX = 0,
	SwingSeatCenterY = -2.82,
	SwingSeatCenterZ = -0.065,
	SwingSeatTop = -5.26,
	SwingRiderHip = 1.25,
	SwingSeatFlip = true,

	-- Pirate ship (unscaled OBJ units from ParkParkPirateBase/Ship.obj). The ship hangs from an axle along X and
	-- swings back and forth along Z; the swing widens and narrows over PirateCycleSeconds. PirateShipCenterY is
	-- the ship mesh's bounding-box centre below its axle (the OBJ origin), PirateSeatTop the bench height below
	-- the axle, PirateBenchZ the four bench rows, and PirateSeatColumnX the two seats on each bench.
	PirateSeatCount = 8,
	PirateHubHeight = 9,
	PiratePlatformRadius = 8,
	PirateShipCenterY = -3.775,
	PirateSeatTop = -6.65,
	PirateBenchZ = { -3.4, -1.9, 1.9, 3.4 },
	PirateSeatColumnX = 0.9,
	PirateRiderHip = 1.25,
	PirateSwingSeconds = 4.6,
	PirateCycleSeconds = 30,
	PirateMinAngle = 24,
	PirateMaxAngle = 62,

	-- Haunted house: guests walk in through the door and are out of sight while they are inside (up to
	-- HauntedSeatCount at once). The windows flicker while anyone is in there. Model numbers are unscaled OBJ
	-- units from ParkParkHauntedHouse.obj.
	HauntedSeatCount = 8,

	-- Roller coaster (unscaled OBJ units from ParkParkCoasterTrack/Car.obj; the track's centre line is the generated
	-- CoasterPath). The train docks at the station for CoasterDockSeconds, guests board only then, and a trip ends
	-- when the train next docks. Speeds are in studs per second: the lift is a crawl, and elsewhere the speed
	-- comes from the height below CoasterTopHeight (units) with CoasterGravity, never below CoasterMinSpeed.
	CoasterSeatCount = 8,
	CoasterCarCount = 2,
	CoasterCarSpacing = 4.6,
	CoasterDockSeconds = 9,
	CoasterLiftSpeed = 7,
	CoasterStationSpeed = 8,
	CoasterMinSpeed = 9,
	CoasterGravity = 12,
	CoasterTopHeight = 15,
	CoasterCarCenterY = 0.585,
	CoasterSeatTop = 0.86,
	CoasterRowZ = 0.65,
	CoasterColumnX = 0.5,
	CoasterRiderHip = 1.25,

	-- Log flume (unscaled OBJ units from ParkParkFlumeTrack/Boat.obj; the channel's centre line is the generated
	-- FlumePath). It runs through TrackService like the roller coaster: boats dock at the station, climb the lift,
	-- and plunge. FlumeCarCenterY is the boat mesh's bounding-box centre above the water, FlumeSeatTop the bench top.
	FlumeSeatCount = 8,
	FlumeCarCount = 2,
	FlumeCarSpacing = 5,
	FlumeDockSeconds = 9,
	FlumeLiftSpeed = 8,
	FlumeStationSpeed = 8,
	FlumeMinSpeed = 8,
	FlumeGravity = 9,
	FlumeTopHeight = 11,
	FlumeCarCenterY = 0.4,
	FlumeSeatTop = 0.65,
	FlumeRowZ = 0.7,
	FlumeColumnX = 0.5,
	FlumeRiderHip = 1.25,

	-- Janitors: hired at the cleaning cart by the entrance path, they walk to litter and clear it for free.
	-- Costs are for the 1st, 2nd, ... janitor.
	JanitorCosts = { 60, 140, 240 },
	JanitorWalkSpeed = 12,
	JanitorCleanSeconds = 1.6,

	-- Power outage: now and then the park loses power. Every attraction stops and the lights dim until a
	-- player switches the generator by the entrance back on; it also comes back on its own after a while.
	PowerOutageMinSeconds = 240,
	PowerOutageMaxSeconds = 360,
	PowerOutageTimeoutSeconds = 60,
	PowerRestoreReward = 40,
	PowerOutageMinRides = 3,

	-- Snack stand: guests at the counter buy a snack and eat it for a few seconds.
	SnackCounterSeats = 3,
	SnackServeSeconds = 4,

	-- Guests arrive only after the park opens, walk along the paths, queue at a ride, and wait for a
	-- player (or that ride's staff) to let them on.
	MaxGuests = 10,
	GuestSpawnSeconds = 6,
	GuestRideSeconds = 16,
	GuestWalkSpeed = 14,
	QueueMax = 6,
	QueueSpacing = 5,
	GuestPatienceSeconds = 75,
	-- After a ride a guest may join another random ride this many more times.
	GuestExtraRideChance = 0.5,
	GuestMaxRides = 3,

	Palette = {
		Ink = Color3.fromRGB(57, 67, 72),
		Cream = Color3.fromRGB(255, 241, 210),
		Coral = Color3.fromRGB(244, 127, 112),
		Gold = Color3.fromRGB(255, 215, 122),
		Mint = Color3.fromRGB(96, 178, 146),
	},
}
