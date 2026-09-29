--!strict

local parkBuilder = require(script.Parent.Services.ParkBuilder)
local bumperCarService = require(script.Parent.Services.BumperCarService)
local economyService = require(script.Parent.Services.EconomyService)
local guestService = require(script.Parent.Services.GuestService)
local noticeService = require(script.Parent.Services.NoticeService)
local parkProgressionService = require(script.Parent.Services.ParkProgressionService)
local rideService = require(script.Parent.Services.RideService)

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
	noticeService.Send
)
bumperCarService.Start(park)
guestService.Start(park, economyService.AwardCoins, noticeService.Send)

local function source(model: Model): string
	return if model:GetAttribute("IsGraybox") == true then "graybox" else "authored"
end

print(
	string.format(
		"[ParkPark] Park ready (entrance=%s, carousel=%s, teacups=%s, bumper=%s)",
		source(park.Entrance),
		source(park.Carousel),
		source(park.TeacupsRide),
		source(park.BumperRide)
	)
)

print("[ParkPark] Server bootstrap loaded")
