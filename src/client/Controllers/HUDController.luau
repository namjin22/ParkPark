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
	shadow.Name = "CoinCardShadow"
	shadow.Position = UDim2.fromOffset(18, 22)
	shadow.Size = UDim2.fromOffset(210, 64)
	shadow.BackgroundColor3 = GameConfig.Palette.Ink
	shadow.BackgroundTransparency = 0.82
	shadow.BorderSizePixel = 0
	shadow.Parent = screenGui
	addCorner(shadow, 18)

	local card = Instance.new("Frame")
	card.Name = "CoinCard"
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
	icon.Name = "CoinIcon"
	icon.Size = UDim2.fromOffset(38, 38)
	icon.BackgroundColor3 = GameConfig.Palette.Gold
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
	iconText.TextColor3 = GameConfig.Palette.Ink
	iconText.TextSize = 22
	iconText.Parent = icon

	local textColumn = Instance.new("Frame")
	textColumn.Name = "CoinText"
	textColumn.Size = UDim2.new(1, -49, 1, 0)
	textColumn.BackgroundTransparency = 1
	textColumn.LayoutOrder = 2
	textColumn.Parent = card

	local title = Instance.new("TextLabel")
	title.Name = "CoinTitle"
	title.Position = UDim2.fromOffset(0, 9)
	title.Size = UDim2.new(1, 0, 0, 16)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamMedium
	title.Text = GameConfig.CurrencyDisplayName
	title.TextColor3 = GameConfig.Palette.Ink
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = textColumn

	local count = Instance.new("TextLabel")
	count.Name = "CoinCount"
	count.Position = UDim2.fromOffset(0, 25)
	count.Size = UDim2.new(1, 0, 0, 28)
	count.BackgroundTransparency = 1
	count.Font = Enum.Font.GothamBold
	count.TextColor3 = GameConfig.Palette.Ink
	count.TextSize = 23
	count.TextXAlignment = Enum.TextXAlignment.Left
	count.TextYAlignment = Enum.TextYAlignment.Top
	count.Parent = textColumn

	-- The park's star rating sits at the top right of the coin card; the server owns it as `Rating`.
	local starLabel = Instance.new("TextLabel")
	starLabel.Name = "RatingStars"
	starLabel.Position = UDim2.fromOffset(0, 9)
	starLabel.Size = UDim2.new(1, 0, 0, 16)
	starLabel.BackgroundTransparency = 1
	starLabel.Font = Enum.Font.GothamBold
	starLabel.RichText = true
	starLabel.TextSize = 13
	starLabel.TextXAlignment = Enum.TextXAlignment.Right
	starLabel.Parent = textColumn
	local starGold = "#F2B744"
	local starGray = "#C9BFA8"
	local function showRating(stars: number)
		local text = ""
		for index = 1, 5 do
			text ..= string.format('<font color="%s">★</font>', if index <= stars then starGold else starGray)
		end
		starLabel.Text = text
	end
	showRating(1)
	task.spawn(function()
		local world = workspace:WaitForChild("ParkParkWorld")
		showRating((world:GetAttribute("Rating") :: number?) or 1)
		world:GetAttributeChangedSignal("Rating"):Connect(function()
			showRating((world:GetAttribute("Rating") :: number?) or 1)
		end)
	end)

	local leaderstats = player:WaitForChild("leaderstats")
	local coins = leaderstats:WaitForChild("Coins") :: IntValue
	local displayedCoins = coins.Value
	count.Text = tostring(displayedCoins)

	-- A small "+N" / "-N" beside the balance shows each change without any popup in the middle of the screen.
	local changeLabel = Instance.new("TextLabel")
	changeLabel.Name = "CoinChange"
	changeLabel.Position = UDim2.fromOffset(150, 48)
	changeLabel.Size = UDim2.fromOffset(72, 24)
	changeLabel.BackgroundTransparency = 1
	changeLabel.Font = Enum.Font.GothamBlack
	changeLabel.TextSize = 18
	changeLabel.TextXAlignment = Enum.TextXAlignment.Left
	changeLabel.TextTransparency = 1
	changeLabel.TextStrokeColor3 = GameConfig.Palette.Ink
	changeLabel.TextStrokeTransparency = 1
	changeLabel.Parent = screenGui
	local changeToken = 0

	local function showChange(delta: number)
		changeToken += 1
		local token = changeToken
		changeLabel.Text = if delta > 0 then string.format("+%d", delta) else string.format("%d", delta)
		changeLabel.TextColor3 = if delta > 0 then GameConfig.Palette.Mint else GameConfig.Palette.Coral
		changeLabel.Position = UDim2.fromOffset(150, 56)
		changeLabel.TextTransparency = 0
		changeLabel.TextStrokeTransparency = 0.6
		TweenService:Create(changeLabel, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(150, 44),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(1.2, function()
			if token == changeToken then
				changeLabel.TextTransparency = 1
			end
		end)
	end

	coins:GetPropertyChangedSignal("Value"):Connect(function()
		count.Text = tostring(coins.Value)
		if coins.Value == displayedCoins then
			return
		end
		showChange(coins.Value - displayedCoins)
		displayedCoins = coins.Value

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
