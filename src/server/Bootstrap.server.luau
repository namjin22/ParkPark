--!strict

local parkBuilder = require(script.Parent.Services.ParkBuilder)
local bumperCarService = require(script.Parent.Services.BumperCarService)
local ferrisService = require(script.Parent.Services.FerrisService)
local economyService = require(script.Parent.Services.EconomyService)
local guestService = require(script.Parent.Services.GuestService)
local litterService = require(script.Parent.Services.LitterService)
local noticeService = require(script.Parent.Services.NoticeService)
local parkProgressionService = require(script.Parent.Services.ParkProgressionService)
local rideService = require(script.Parent.Services.RideService)
local teacupService = require(script.Parent.Services.TeacupService)

-- Create leaderstats before the builder's bounded asset waits so the HUD never stalls.
economyService.Initialize()
noticeService.Initialize()
print("[ParkPark] Building park world")
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
	noticeService.Send
)
bumperCarService.Start(park)
teacupService.Start(park)
ferrisService.Start(park)
guestService.Start(park, economyService.AwardCoins, noticeService.Send, noticeService.Popup)
litterService.Start(park, economyService.AwardCoins, noticeService.Popup, parkBuilder.FindLitterTemplate)

local function source(model: Model): string
	return if model:GetAttribute("IsGraybox") == true then "graybox" else "authored"
end

print(
	string.format(
		"[ParkPark] Park ready (entrance=%s, carousel=%s, teacups=%s%s, bumper=%s, snack=%s, ferris=%s)",
		source(park.Entrance),
		source(park.Carousel),
		source(park.TeacupsRide),
		if park.TeacupCups then "+cups" else "",
		source(park.BumperRide),
		source(park.SnackStand),
		source(park.FerrisRide)
	)
)

print("[ParkPark] Server bootstrap loaded")
