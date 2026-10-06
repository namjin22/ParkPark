--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- A small quest card at the top right that shows the park's current quest (published by QuestService on the
-- park folder): title, what to do, a progress bar, and the reward. It hides when there is no quest.
local QuestController = {}

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function QuestController.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local park = Workspace:WaitForChild("ParkParkWorld")
	local palette = GameConfig.Palette

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ParkParkQuest"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 11
	screenGui.Parent = playerGui

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(1, 0)
	card.Position = UDim2.new(1, -12, 0, 110)
	card.Size = UDim2.fromOffset(240, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = palette.Cream
	card.BorderSizePixel = 0
	card.Visible = false
	card.Parent = screenGui
	addCorner(card, 16)

	local function updateLayout()
		local camera = Workspace.CurrentCamera
		local compactPortrait = camera ~= nil
			and camera.ViewportSize.X < 550
			and camera.ViewportSize.Y > camera.ViewportSize.X
		if compactPortrait then
			card.AnchorPoint = Vector2.new(0, 0)
			card.Position = UDim2.fromOffset(16, 160)
			card.Size = UDim2.new(1, -32, 0, 0)
		else
			card.AnchorPoint = Vector2.new(1, 0)
			card.Position = UDim2.new(1, -12, 0, 110)
			card.Size = UDim2.fromOffset(240, 0)
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
	bindCamera()

	local stroke = Instance.new("UIStroke")
	stroke.Color = palette.Coral
	stroke.Thickness = 3
	stroke.Parent = card
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = card

	local function label(size: number, bold: boolean, color: Color3, order: number): TextLabel
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.new(1, 0, 0, size + 4)
		text.AutomaticSize = Enum.AutomaticSize.Y
		text.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
		text.TextSize = size
		text.TextColor3 = color
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextWrapped = true
		text.LayoutOrder = order
		text.Parent = card
		return text
	end
	local title = label(18, true, palette.Ink, 1)
	local desc = label(14, false, palette.Ink, 2)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 12)
	bar.BackgroundColor3 = Color3.fromRGB(226, 214, 190)
	bar.BorderSizePixel = 0
	bar.LayoutOrder = 3
	bar.Parent = card
	addCorner(bar, 6)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = palette.Mint
	fill.BorderSizePixel = 0
	fill.Parent = bar
	addCorner(fill, 6)
	local reward = label(14, true, Color3.fromRGB(206, 78, 64), 4)

	local function refresh()
		local name = park:GetAttribute("QuestTitle")
		if type(name) ~= "string" then
			card.Visible = false
			return
		end
		local target = (park:GetAttribute("QuestTarget") :: number?) or 1
		local progress = (park:GetAttribute("QuestProgress") :: number?) or 0
		title.Text = "퀘스트 · " .. name
		desc.Text = string.format("%s (%d/%d)", (park:GetAttribute("QuestDesc") :: string?) or "", progress, target)
		fill.Size = UDim2.fromScale(math.clamp(progress / math.max(target, 1), 0, 1), 1)
		reward.Text = string.format(
			"보상 +%d %s",
			(park:GetAttribute("QuestReward") :: number?) or 0,
			GameConfig.CurrencyDisplayName
		)
		card.Visible = true
	end
	for _, attribute in { "QuestTitle", "QuestDesc", "QuestProgress", "QuestTarget", "QuestReward" } do
		park:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	refresh()
end

return QuestController
