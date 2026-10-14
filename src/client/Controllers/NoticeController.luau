--!strict

local UITheme = require(
	game:GetService("ReplicatedStorage"):WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("UITheme")
)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Shows server notices (coins earned/spent, missing coins, park opening) one toast at a time.
local NoticeController = {}

local SHOW_SECONDS = 2.2

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.clamp(math.floor(radius / 2), 4, 10))
	corner.Parent = parent
end

function NoticeController.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local park = Workspace:WaitForChild("ParkParkWorld")
	local noticeEvent = ReplicatedStorage:WaitForChild("ParkParkEvents"):WaitForChild("Notice") :: RemoteEvent

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ParkParkNotices"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 11
	screenGui.Parent = playerGui

	local card = Instance.new("Frame")
	card.Name = "NoticeToast"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 152)
	card.Size = UDim2.new(0.9, 0, 0, 50)
	card.BackgroundColor3 = UITheme.Panel
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.Visible = false
	card.Parent = screenGui
	addCorner(card, 18)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(220, 50)
	sizeConstraint.MaxSize = Vector2.new(320, 50)
	sizeConstraint.Parent = card

	local function compactPortrait(): boolean
		local camera = Workspace.CurrentCamera
		return camera ~= nil and camera.ViewportSize.X < 550 and camera.ViewportSize.Y > camera.ViewportSize.X
	end
	-- Portrait phones: below the guide and quest cards. Wide screens: bottom centre between the thumbstick and jump
	-- button, away from the card column on the left and the quest card on the right.
	local function restPosition(visible: boolean): UDim2
		if compactPortrait() then
			local top = if type(park:GetAttribute("QuestTitle")) == "string" then 220 else 130
			return UDim2.new(0.5, 0, 0, if visible then top + 10 else top)
		end
		return UDim2.new(0.5, 0, 1, if visible then -24 else 0)
	end
	local function updateLayout()
		local portrait = compactPortrait()
		card.AnchorPoint = if portrait then Vector2.new(0.5, 0) else Vector2.new(0.5, 1)
		card.Size = UDim2.new(if portrait then 0.76 else 0.9, 0, 0, 50)
		if card.Visible then
			card.Position = restPosition(true)
		end
	end
	local function bindCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
		end
		updateLayout()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	park:GetAttributeChangedSignal("QuestTitle"):Connect(updateLayout)
	bindCamera()

	local outline = Instance.new("UIStroke")
	outline.Color = UITheme.Border
	outline.Thickness = 1
	outline.Transparency = 1
	outline.Parent = card

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Position = UDim2.fromOffset(0, 8)
	accent.Size = UDim2.fromOffset(4, 34)
	accent.BackgroundColor3 = UITheme.Accent
	accent.BackgroundTransparency = 1
	accent.BorderSizePixel = 0
	accent.Parent = card
	addCorner(accent, 3)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -24, 0, 20)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = UITheme.Text
	title.TextSize = 14
	title.TextTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Parent = card

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.Position = UDim2.fromOffset(12, 27)
	detail.Size = UDim2.new(1, -24, 0, 16)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.GothamMedium
	detail.TextColor3 = UITheme.Text
	detail.TextSize = 12
	detail.TextTransparency = 1
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextTruncate = Enum.TextTruncate.AtEnd
	detail.Parent = card

	local queue: { { title: string, detail: string } } = {}
	local showing = false

	local function fade(visible: boolean, duration: number)
		local target = if visible then 0 else 1
		TweenService:Create(card, TweenInfo.new(duration, Enum.EasingStyle.Quad), {
			Position = restPosition(visible),
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
		card.Position = restPosition(false)
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
