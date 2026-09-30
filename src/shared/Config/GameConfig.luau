--!strict

export type RideEconomy = {
	DisplayName: string,
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

	Rides = {
		Carousel = {
			DisplayName = "회전목마",
			UnlockCost = 0,
			RepairCost = 25,
			BaseFare = 5,
			IncomePerLevel = 3,
			IncomeCosts = { 40, 90, 160, 260 },
			StaffCosts = { 70, 150, 260 },
		},
		Teacups = {
			DisplayName = "찻잔 라이드",
			UnlockCost = 60,
			RepairCost = 35,
			BaseFare = 8,
			IncomePerLevel = 4,
			IncomeCosts = { 60, 130, 230, 360 },
			StaffCosts = { 100, 200, 340 },
		},
		Bumper = {
			DisplayName = "범퍼카",
			UnlockCost = 120,
			RepairCost = 60,
			BaseFare = 12,
			IncomePerLevel = 6,
			IncomeCosts = { 90, 190, 320, 500 },
			StaffCosts = { 140, 280, 450 },
		},
		Snack = {
			DisplayName = "간식 판매대",
			UnlockCost = 40,
			RepairCost = 30,
			BaseFare = 4,
			IncomePerLevel = 2,
			IncomeCosts = { 30, 70, 130, 220 },
			StaffCosts = { 60, 120, 220 },
			IsShop = true,
		},
	} :: { [string]: RideEconomy },
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
