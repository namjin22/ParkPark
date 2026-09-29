--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Server-to-client toasts (reward, cost, and "not enough coins" feedback).
local NoticeService = {}

local noticeEvent: RemoteEvent? = nil

function NoticeService.Initialize()
	local folder = ReplicatedStorage:FindFirstChild("ParkParkEvents")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "ParkParkEvents"
		folder.Parent = ReplicatedStorage
	end

	local existing = (folder :: Instance):FindFirstChild("Notice")
	if existing and existing:IsA("RemoteEvent") then
		noticeEvent = existing
		return
	end

	local event = Instance.new("RemoteEvent")
	event.Name = "Notice"
	event.Parent = folder
	noticeEvent = event
end

function NoticeService.Send(player: Player, title: string, detail: string)
	if noticeEvent then
		noticeEvent:FireClient(player, title, detail)
	end
end

return NoticeService
