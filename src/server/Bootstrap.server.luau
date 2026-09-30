--!strict

local parkBuilder = require(script.Parent.Services.ParkBuilder)
local bumperCarService = require(script.Parent.Services.BumperCarService)
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
	parkBuilder.ApplySwingRepairedAppearance,
	noticeService.Send
)
bumperCarService.Start(park)
teacupService.Start(park)
ferrisService.Start(park)
swingService.Start(park)
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
	litter
)

local function source(model: Model): string
	return if model:GetAttribute("IsGraybox") == true then "graybox" else "authored"
end

print(
	string.format(
		"[ParkPark] Park ready (entrance=%s, carousel=%s, teacups=%s%s, bumper=%s, snack=%s, ferris=%s, swing=%s)",
		source(park.Entrance),
		source(park.Carousel),
		source(park.TeacupsRide),
		if park.TeacupCups then "+cups" else "",
		source(park.BumperRide),
		source(park.SnackStand),
		source(park.FerrisRide),
		source(park.SwingRide)
	)
)

print("[ParkPark] Server bootstrap loaded")
