--!strict

local parkBuilder = require(script.Parent.Services.ParkBuilder)
local economyService = require(script.Parent.Services.EconomyService)
local rideService = require(script.Parent.Services.RideService)

local park = parkBuilder.Build()
economyService.Initialize()
rideService.Start(park, economyService.AwardTickets, parkBuilder.ApplyRepairedGrayboxAppearance)

print("[ParkPark] Server bootstrap loaded")
