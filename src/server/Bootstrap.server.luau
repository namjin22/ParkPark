--!strict

local parkBuilder = require(script.Parent.Services.ParkBuilder)
local economyService = require(script.Parent.Services.EconomyService)
local parkProgressionService = require(script.Parent.Services.ParkProgressionService)
local rideService = require(script.Parent.Services.RideService)

local park = parkBuilder.Build()
economyService.Initialize()
parkProgressionService.Start(park, economyService.AwardTickets)
rideService.Start(park, economyService.AwardTickets, parkBuilder.ApplyRepairedAppearance)

print("[ParkPark] Server bootstrap loaded")
