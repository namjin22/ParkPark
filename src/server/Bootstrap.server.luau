--!strict

local parkBuilder = require(script.Parent.Services.ParkBuilder)
local economyService = require(script.Parent.Services.EconomyService)
local parkProgressionService = require(script.Parent.Services.ParkProgressionService)
local rideService = require(script.Parent.Services.RideService)

-- Create leaderstats before the builder's bounded asset waits so the HUD never stalls.
economyService.Initialize()
print("[ParkPark] Building park world")
local park = parkBuilder.Build()
parkProgressionService.Start(park, economyService.AwardTickets, parkBuilder.ApplyEntranceRestored)
rideService.Start(park, economyService.AwardTickets, parkBuilder.ApplyRepairedAppearance)

local entranceSource = if park.Entrance:GetAttribute("IsGraybox") == true then "graybox" else "authored"
local carouselSource = if park.Carousel:GetAttribute("IsGraybox") == true then "graybox" else "authored"
print(string.format("[ParkPark] Park ready (entrance=%s, carousel=%s)", entranceSource, carouselSource))

print("[ParkPark] Server bootstrap loaded")
