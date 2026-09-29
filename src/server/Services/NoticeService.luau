--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Server-to-client feedback. Notices are milestone toasts (unlock, repair, opening, upgrades, missing
-- coins); popups are small floating "+N" texts in the world for coins earned from guests and litter.
local NoticeService = {}

local noticeEvent: RemoteEvent? = nil
local popupEvent: RemoteEvent? = nil

local function getOrCreateEvent(folder: Instance, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	return event
end

function NoticeService.Initialize()
	local folder = ReplicatedStorage:FindFirstChild("ParkParkEvents")
	if folder == nil then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "ParkParkEvents"
		newFolder.Parent = ReplicatedStorage
		folder = newFolder
	end

	noticeEvent = getOrCreateEvent(folder :: Instance, "Notice")
	popupEvent = getOrCreateEvent(folder :: Instance, "CoinPopup")
end

function NoticeService.Send(player: Player, title: string, detail: string)
	if noticeEvent then
		noticeEvent:FireClient(player, title, detail)
	end
end

-- Floating text at a world position, shown to every player.
function NoticeService.Popup(position: Vector3, text: string)
	if popupEvent then
		popupEvent:FireAllClients(position, text)
	end
end

return NoticeService
