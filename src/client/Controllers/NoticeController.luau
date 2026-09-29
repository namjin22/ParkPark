--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Shows server notices (coins earned/spent, missing coins, park opening) one toast at a time.
local NoticeController = {}

local SHOW_SECONDS = 2.6

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function NoticeController.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local noticeEvent = ReplicatedStorage:WaitForChild("ParkParkEvents"):WaitForChild("Notice") :: RemoteEvent

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ParkParkNotices"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 11
	screenGui.Parent = playerGui

	local card = Instance.new("Frame")
	card.Name = "NoticeToast"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 66)
	card.Size = UDim2.new(0.84, 0, 0, 72)
	card.BackgroundColor3 = GameConfig.Palette.Cream
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.Visible = false
	card.Parent = screenGui
	addCorner(card, 18)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(240, 72)
	sizeConstraint.MaxSize = Vector2.new(340, 72)
	sizeConstraint.Parent = card

	local outline = Instance.new("UIStroke")
	outline.Color = GameConfig.Palette.Gold
	outline.Thickness = 1.5
	outline.Transparency = 1
	outline.Parent = card

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Position = UDim2.fromOffset(0, 12)
	accent.Size = UDim2.fromOffset(6, 48)
	accent.BackgroundColor3 = GameConfig.Palette.Coral
	accent.BackgroundTransparency = 1
	accent.BorderSizePixel = 0
	accent.Parent = card
	addCorner(accent, 3)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(20, 13)
	title.Size = UDim2.new(1, -34, 0, 22)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = GameConfig.Palette.Ink
	title.TextSize = 17
	title.TextTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.Position = UDim2.fromOffset(20, 38)
	detail.Size = UDim2.new(1, -34, 0, 18)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.GothamMedium
	detail.TextColor3 = GameConfig.Palette.Ink
	detail.TextSize = 13
	detail.TextTransparency = 1
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.Parent = card

	local queue: { { title: string, detail: string } } = {}
	local showing = false

	local function fade(visible: boolean, duration: number)
		local target = if visible then 0 else 1
		TweenService:Create(card, TweenInfo.new(duration, Enum.EasingStyle.Quad), {
			Position = UDim2.new(0.5, 0, 0, if visible then 78 else 66),
			BackgroundTransparency = target,
		}):Play()
		TweenService:Create(outline, TweenInfo.new(duration), { Transparency = if visible then 0.15 else 1 }):Play()
		TweenService:Create(accent, TweenInfo.new(duration), { BackgroundTransparency = target }):Play()
		TweenService:Create(title, TweenInfo.new(duration), { TextTransparency = target }):Play()
		TweenService:Create(detail, TweenInfo.new(duration), { TextTransparency = if visible then 0.12 else 1 }):Play()
	end

	local function showNext()
		local nextNotice = table.remove(queue, 1)
		if nextNotice == nil then
			showing = false
			return
		end

		showing = true
		title.Text = nextNotice.title
		detail.Text = nextNotice.detail
		card.Visible = true
		fade(true, 0.22)
		task.delay(SHOW_SECONDS, function()
			fade(false, 0.18)
			task.delay(0.2, function()
				card.Visible = false
				showNext()
			end)
		end)
	end

	noticeEvent.OnClientEvent:Connect(function(noticeTitle: unknown, noticeDetail: unknown)
		if type(noticeTitle) ~= "string" or type(noticeDetail) ~= "string" then
			return
		end
		-- Keep the queue short so frequent ride fares never lag far behind.
		if #queue >= 3 then
			table.remove(queue, 1)
		end
		table.insert(queue, { title = noticeTitle, detail = noticeDetail })
		if not showing then
			showNext()
		end
	end)
end

return NoticeController
