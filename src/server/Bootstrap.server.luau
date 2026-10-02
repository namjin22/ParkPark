--!strict

local persistenceService = require(script.Parent.Services.PersistenceService)
local parkBuilder = require(script.Parent.Services.ParkBuilder)
local bumperCarService = require(script.Parent.Services.BumperCarService)
local decorService = require(script.Parent.Services.DecorService)
local trackService = require(script.Parent.Services.TrackService)
local configFolder = game:GetService("ReplicatedStorage"):WaitForChild("ParkRebornShared"):WaitForChild("Config")
local gameConfig = require(configFolder:WaitForChild("GameConfig"))
local coasterPath = require(configFolder:WaitForChild("CoasterPath"))
local flumePath = require(configFolder:WaitForChild("FlumePath"))
local trainPath = require(configFolder:WaitForChild("TrainPath"))
local dropService = require(script.Parent.Services.DropService)
local zoneService = require(script.Parent.Services.ZoneService)
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
local eventService = require(script.Parent.Services.EventService)
local goalService = require(script.Parent.Services.GoalService)
local dayNightService = require(script.Parent.Services.DayNightService)
local questService = require(script.Parent.Services.QuestService)
local speedShopService = require(script.Parent.Services.SpeedShopService)
local mechanicService = require(script.Parent.Services.MechanicService)
local decorShopService = require(script.Parent.Services.DecorShopService)
local snowService = require(script.Parent.Services.SnowService)
local spaceService = require(script.Parent.Services.SpaceService)
local dailyService = require(script.Parent.Services.DailyService)
local travelService = require(script.Parent.Services.TravelService)
local extraRideService = require(script.Parent.Services.ExtraRideService)

-- Create leaderstats before the builder's bounded asset waits so the HUD never stalls.
economyService.SetStartingCoinsProvider(persistenceService.LoadCoins)
economyService.Initialize()
noticeService.Initialize()
-- The first player to join hosts the park: their saved park (if any) is what gets built.
local savedPark = persistenceService.LoadParkState()
parkBuilder.SetSavedState(savedPark :: any)
print(if savedPark then "[ParkPark] Building park world from a saved game" else "[ParkPark] Building park world")
local park = parkBuilder.Build()
extraRideService.Build(park, if savedPark then savedPark.Rides else nil)
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
	parkBuilder.ApplyFlumeRepairedAppearance,
	parkBuilder.ApplyDropRepairedAppearance,
	parkBuilder.ApplyGiftRepairedAppearance,
	parkBuilder.ApplyTrainRepairedAppearance,
	parkBuilder.ApplyExtraRepairedAppearance,
	noticeService.Send
)
extraRideService.Start(park)
travelService.Start(park)
eventService.Start(park, noticeService.Send)
goalService.Start(park, economyService.AwardCoins, noticeService.Send)
mechanicService.Start(park, economyService.SpendCoins, noticeService.Send)
decorShopService.Start(park, economyService.SpendCoins, noticeService.Send, parkBuilder.FindDecorTemplate)
snowService.Start(park)
spaceService.Start(park)
speedShopService.Start(
	park,
	economyService.SpendCoins,
	noticeService.Send,
	persistenceService.GetSpeedLevel,
	persistenceService.SetSpeedLevel
)
dailyService.Start(
	park,
	economyService.AwardCoins,
	noticeService.Send,
	persistenceService.GetDaily,
	persistenceService.SetDaily
)
dayNightService.Start(park, noticeService.Send)
bumperCarService.Start(park)
teacupService.Start(park)
ferrisService.Start(park)
swingService.Start(park)
pirateService.Start(park)
hauntedService.Start(park)
trackService.Start({
	Ride = park.CoasterRide,
	Cars = park.CoasterCars,
	Path = coasterPath,
	CarPrefix = "CoasterCar",
	ConfigPrefix = "Coaster",
})
trackService.Start({
	Ride = park.FlumeRide,
	Cars = park.FlumeCars,
	Path = flumePath,
	CarPrefix = "FlumeCar",
	ConfigPrefix = "Flume",
})
trackService.Start({
	Ride = park.TrainRide,
	Cars = park.TrainCars,
	Path = trainPath,
	CarPrefix = "TrainCar",
	ConfigPrefix = "Train",
})
dropService.Start(park)
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
	Flume = park.FlumeRide,
	Drop = park.DropRide,
	Gift = park.GiftShop,
	Train = park.TrainRide,
}
for key, extra in park.Extras do
	rideModels[key] = extra.Ride
end
zoneService.Start(park, rideModels, economyService.SpendCoins, economyService.GetCoins, noticeService.Send)
questService.Start(park, rideModels, economyService.AwardCoins, noticeService.Send)
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
	local parkState: { [string]: any } = {
		EntranceCleared = park.ParkFolder:GetAttribute("EntranceCleared") == true,
		ParkOpen = park.ParkFolder:GetAttribute("ParkOpen") == true,
		GuestsBoarded = (park.ParkFolder:GetAttribute("GuestsBoarded") :: number?) or 0,
		GoalsClaimed = (park.ParkFolder:GetAttribute("GoalsClaimed") :: number?) or 0,
		QuestIndex = (park.ParkFolder:GetAttribute("QuestIndex") :: number?) or 0,
		Mechanics = (park.ParkFolder:GetAttribute("Mechanics") :: number?) or 0,
		PlotsBought = (park.ParkFolder:GetAttribute("PlotsBought") :: number?) or 0,
	}
	for zone in gameConfig.ZoneCosts do
		parkState["Zone_" .. zone] = park.ParkFolder:GetAttribute("Zone_" .. zone) == true
	end
	return {
		Park = parkState :: any,
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
