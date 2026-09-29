--!strict

return {
	-- Economy: cleanup earns coins, repairs spend them, and guest rides pay them back.
	StartingCoins = 0,
	CurrencyDisplayName = "코인",
	EntranceCleanupReward = 30,
	CarouselRepairCost = 25,
	GuestRideFare = 5,

	-- Carousel ride. CarouselScale must match S in tools/build_parkpark_templates.py.
	CarouselRotationSeconds = 16,
	CarouselScale = 1.6,
	CarouselSeatCount = 8,

	-- The teacups unlock after the park opens; both mesh scales must match the template builder.
	TeacupsUnlockCost = 60,
	TeacupsRepairCost = 35,
	TeacupsGuestRideFare = 8,
	TeacupsRotationSeconds = 12,
	TeacupsScale = 1,
	TeacupsPlatformRadius = 9.2,
	TeacupsSeatCount = 6,
	TeacupsSeatRadius = 6,
	TeacupsSeatHeight = 1.28,
	TeacupsRotorCenterHeight = 4.72,
	TeacupsRiderHip = 1.05,

	-- Guests arrive only after the park opens.
	MaxGuests = 6,
	GuestSpawnSeconds = 5,
	GuestRideSeconds = 16,

	Palette = {
		Ink = Color3.fromRGB(57, 67, 72),
		Cream = Color3.fromRGB(255, 241, 210),
		Coral = Color3.fromRGB(244, 127, 112),
		Gold = Color3.fromRGB(255, 215, 122),
		Mint = Color3.fromRGB(96, 178, 146),
	},
}
