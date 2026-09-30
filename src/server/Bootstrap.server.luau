--!strict

local persistenceService = require(script.Parent.Services.PersistenceService)
local parkBuilder = require(script.Parent.Services.ParkBuilder)
local bumperCarService = require(script.Parent.Services.BumperCarService)
local decorService = require(script.Parent.Services.DecorService)
local coasterService = require(script.Parent.Services.CoasterService)
local hauntedService = require(script.Parent.Services.HauntedService)
local pirateService = require(script.Parent.Services.PirateService)
local swingService = require(script.Parent.Services.SwingService)
local ferrisService = require(script.Parent.Services.FerrisService)
local economyService = require(script.Parent.Services.EconomyService)
local guestService = require(script.Parent.Services.GuestService)
local janitorService = require(script.Parent.Services.JanitorService)
local litterService = require(script.Parent.Services.LitterService)
local noticeService = require(script.Parent.Services.NoticeService)
local powerService = require(script.Parent.Services.PowerService)
local parkProgressionService = require(script.Parent.Services.ParkProgressionService)
local rideService = require(script.Parent.Services.RideService)
local teacupService = require(script.Parent.Services.TeacupService)

-- Create leaderstats before the builder's bounded asset waits so the HUD never stalls.
economyService.SetStartingCoinsProvider(persistenceService.LoadCoins)
economyService.Initialize()
noticeService.Initialize()
-- The first player to join hosts the park: their saved park (if any) is what gets built.
local savedPark = persistenceService.LoadParkState()
parkBuilder.SetSavedState(savedPark :: any)
print(if savedPark then "[ParkPark] Building park world from a saved game" else "[ParkPark] Building park world")
local park = parkBuilder.Build()
parkProgressionService.Start(park, economyService.AwardCoins, parkBuilder.ApplyEntranceRestored, noticeService.Send)
rideService.Start(
	park,
	economyService.SpendCoins,
	economyService.GetCoins,
	parkBuilder.ApplyRepairedAppearance,
	parkBuilder.ApplyTeacupsRepairedAppearance,
	parkBuilder.ApplyBumperRepairedAppearance,
	parkBuilder.ApplySnackRepairedAppearance,
	parkBuilder.ApplyFerrisRepairedAppearance,
	parkBuilder.ApplySwingRepairedAppearance,
	parkBuilder.ApplyPirateRepairedAppearance,
	parkBuilder.ApplyHauntedRepairedAppearance,
	parkBuilder.ApplyCoasterRepairedAppearance,
	noticeService.Send
)
bumperCarService.Start(park)
teacupService.Start(park)
ferrisService.Start(park)
swingService.Start(park)
pirateService.Start(park)
hauntedService.Start(park)
coasterService.Start(park)
decorService.Start(park, parkBuilder.FindDecorTemplate)
powerService.Start(park, economyService.AwardCoins, noticeService.Send, noticeService.Popup)
guestService.Start(park, economyService.AwardCoins, noticeService.Send, noticeService.Popup)
local litter = litterService.Start(park, economyService.AwardCoins, noticeService.Popup, parkBuilder.FindLitterTemplate)
janitorService.Start(
	park,
	economyService.AwardCoins,
	economyService.SpendCoins,
	economyService.GetCoins,
	noticeService.Send,
	noticeService.Popup,
	litter,
	if savedPark then savedPark.Janitors else 0
)

-- Everything worth keeping is read here, from server-side state only.
local rideModels: { [string]: Model } = {
	Carousel = park.Carousel,
	Teacups = park.TeacupsRide,
	Snack = park.SnackStand,
	Bumper = park.BumperRide,
	Ferris = park.FerrisRide,
	Swing = park.SwingRide,
	Pirate = park.PirateRide,
	Haunted = park.HauntedHouse,
	Coaster = park.CoasterRide,
}
local watched: { Instance } = { park.ParkFolder }
for _, model in rideModels do
	table.insert(watched, model)
end
persistenceService.Start(function()
	local rides: { [string]: any } = {}
	for key, model in rideModels do
		rides[key] = {
			IsUnlocked = model:GetAttribute("IsUnlocked") == true,
			IsRepaired = model:GetAttribute("IsRepaired") == true,
			IncomeLevel = (model:GetAttribute("IncomeLevel") :: number?) or 0,
			StaffLevel = (model:GetAttribute("StaffLevel") :: number?) or 0,
		}
	end
	return {
		Park = {
			EntranceCleared = park.ParkFolder:GetAttribute("EntranceCleared") == true,
			ParkOpen = park.ParkFolder:GetAttribute("ParkOpen") == true,
			GuestsBoarded = (park.ParkFolder:GetAttribute("GuestsBoarded") :: number?) or 0,
		},
		Rides = rides,
		Janitors = (park.ParkFolder:GetAttribute("Janitors") :: number?) or 0,
	}
end, watched)

local function source(model: Model): string
	return if model:GetAttribute("IsGraybox") == true then "graybox" else "authored"
end

print(
	string.format(
		"[ParkPark] Park ready (entrance=%s, carousel=%s, teacups=%s%s, bumper=%s, snack=%s, ferris=%s, swing=%s, pirate=%s, haunted=%s, coaster=%s)",
		source(park.Entrance),
		source(park.Carousel),
		source(park.TeacupsRide),
		if park.TeacupCups then "+cups" else "",
		source(park.BumperRide),
		source(park.SnackStand),
		source(park.FerrisRide),
		source(park.SwingRide),
		source(park.PirateRide),
		source(park.HauntedHouse),
		source(park.CoasterRide)
	)
)

print("[ParkPark] Server bootstrap loaded")
