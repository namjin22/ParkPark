--!strict

local hudController = require(script.Parent.Controllers.HUDController)
local repairFeedbackController = require(script.Parent.Controllers.RepairFeedbackController)

hudController.Start()
repairFeedbackController.Start()

print("[ParkPark] Client bootstrap loaded")
