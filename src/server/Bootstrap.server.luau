--!strict

local parkBuilder = require(script.Parent.Services.ParkBuilder)
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
	noticeService.Send
)
guestService.Start(park, economyService.AwardCoins, noticeService.Send)

local entranceSource = if park.Entrance:GetAttribute("IsGraybox") == true then "graybox" else "authored"
local carouselSource = if park.Carousel:GetAttribute("IsGraybox") == true then "graybox" else "authored"
print(string.format("[ParkPark] Park ready (entrance=%s, carousel=%s)", entranceSource, carouselSource))

print("[ParkPark] Server bootstrap loaded")
