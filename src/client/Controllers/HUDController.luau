--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local HUDController = {}

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function HUDController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local existingGui = playerGui:FindFirstChild("ParkParkHUD")
	if existingGui then
		existingGui:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ParkParkHUD"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 10
	screenGui.Parent = playerGui

	local shadow = Instance.new("Frame")
	shadow.Name = "TicketCardShadow"
	shadow.Position = UDim2.fromOffset(18, 22)
	shadow.Size = UDim2.fromOffset(210, 64)
	shadow.BackgroundColor3 = GameConfig.Palette.Ink
	shadow.BackgroundTransparency = 0.82
	shadow.BorderSizePixel = 0
	shadow.Parent = screenGui
	addCorner(shadow, 18)

	local card = Instance.new("Frame")
	card.Name = "TicketCard"
	card.Position = UDim2.fromOffset(16, 18)
	card.Size = UDim2.fromOffset(210, 64)
	card.BackgroundColor3 = GameConfig.Palette.Cream
	card.BorderSizePixel = 0
	card.Parent = screenGui
	addCorner(card, 18)

	local outline = Instance.new("UIStroke")
	outline.Color = GameConfig.Palette.Gold
	outline.Thickness = 1.5
	outline.Transparency = 0.15
	outline.Parent = card

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = card

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = card

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 11)
	layout.Parent = card

	local icon = Instance.new("Frame")
	icon.Name = "TicketIcon"
	icon.Size = UDim2.fromOffset(38, 38)
	icon.BackgroundColor3 = GameConfig.Palette.Coral
	icon.BorderSizePixel = 0
	icon.LayoutOrder = 1
	icon.Parent = card
	addCorner(icon, 19)

	local iconText = Instance.new("TextLabel")
	iconText.Name = "Sparkle"
	iconText.BackgroundTransparency = 1
	iconText.Size = UDim2.fromScale(1, 1)
	iconText.Font = Enum.Font.GothamBold
	-- GothamBold has no glyph for "✦"; "★" renders in Studio Play.
	iconText.Text = "★"
	iconText.TextColor3 = GameConfig.Palette.Cream
	iconText.TextSize = 22
	iconText.Parent = icon

	local textColumn = Instance.new("Frame")
	textColumn.Name = "TicketText"
	textColumn.Size = UDim2.new(1, -49, 1, 0)
	textColumn.BackgroundTransparency = 1
	textColumn.LayoutOrder = 2
	textColumn.Parent = card

	local title = Instance.new("TextLabel")
	title.Name = "TicketTitle"
	title.Position = UDim2.fromOffset(0, 9)
	title.Size = UDim2.new(1, 0, 0, 16)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamMedium
	title.Text = GameConfig.TicketDisplayName
	title.TextColor3 = GameConfig.Palette.Ink
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = textColumn

	local count = Instance.new("TextLabel")
	count.Name = "TicketCount"
	count.Position = UDim2.fromOffset(0, 25)
	count.Size = UDim2.new(1, 0, 0, 28)
	count.BackgroundTransparency = 1
	count.Font = Enum.Font.GothamBold
	count.TextColor3 = GameConfig.Palette.Ink
	count.TextSize = 23
	count.TextXAlignment = Enum.TextXAlignment.Left
	count.TextYAlignment = Enum.TextYAlignment.Top
	count.Parent = textColumn

	local leaderstats = player:WaitForChild("leaderstats")
	local tickets = leaderstats:WaitForChild("Tickets") :: IntValue
	local displayedTickets = tickets.Value
	count.Text = tostring(displayedTickets)

	tickets:GetPropertyChangedSignal("Value"):Connect(function()
		count.Text = tostring(tickets.Value)
		if tickets.Value == displayedTickets then
			return
		end
		displayedTickets = tickets.Value

		TweenService
			:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.06 })
			:Play()
		task.delay(0.12, function()
			if scale.Parent then
				TweenService
					:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
					:Play()
			end
		end)
	end)
end

return HUDController
