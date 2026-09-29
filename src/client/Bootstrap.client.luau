--!strict

local hudController = require(script.Parent.Controllers.HUDController)
local noticeController = require(script.Parent.Controllers.NoticeController)
local objectiveController = require(script.Parent.Controllers.ObjectiveController)

hudController.Start()
task.spawn(noticeController.Start)
task.spawn(objectiveController.Start)

print("[ParkPark] Client bootstrap loaded")
