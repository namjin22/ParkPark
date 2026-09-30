--!strict

local coinPopupController = require(script.Parent.Controllers.CoinPopupController)
local hudController = require(script.Parent.Controllers.HUDController)
local managePanelController = require(script.Parent.Controllers.ManagePanelController)
local noticeController = require(script.Parent.Controllers.NoticeController)
local powerController = require(script.Parent.Controllers.PowerController)
local objectiveController = require(script.Parent.Controllers.ObjectiveController)

hudController.Start()
task.spawn(noticeController.Start)
task.spawn(coinPopupController.Start)
task.spawn(objectiveController.Start)
task.spawn(powerController.Start)
task.spawn(managePanelController.Start)

print("[ParkPark] Client bootstrap loaded")
