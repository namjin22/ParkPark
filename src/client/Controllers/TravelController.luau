--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- A round "이동" button on the right edge opens a short list of places to jump to: the entrance and every
-- zone that has been opened. The server checks the zone is really open before moving the player.
local TravelController = {}

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function TravelController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local park = Workspace:WaitForChild("ParkParkWorld")
	local event = ReplicatedStorage:WaitForChild("ParkParkEvents"):WaitForChild("Travel") :: RemoteEvent
	local palette = GameConfig.Palette

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ParkParkTravel"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 12
	screenGui.Parent = playerGui

	local toggle = Instance.new("TextButton")
	toggle.AnchorPoint = Vector2.new(1, 0.5)
	toggle.Position = UDim2.new(1, -12, 0.42, 0)
	toggle.Size = UDim2.fromOffset(72, 72)
	toggle.BackgroundColor3 = palette.Gold
	toggle.Font = Enum.Font.GothamBold
	toggle.Text = "이동"
	toggle.TextColor3 = palette.Ink
	toggle.TextSize = 22
	toggle.Parent = screenGui
	addCorner(toggle, 36)
	local stroke = Instance.new("UIStroke")
	stroke.Color = palette.Cream
	stroke.Thickness = 3
	stroke.Parent = toggle

	local list = Instance.new("Frame")
	list.AnchorPoint = Vector2.new(1, 0.5)
	list.Position = UDim2.new(1, -92, 0.42, 0)
	list.Size = UDim2.fromOffset(210, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.BackgroundColor3 = palette.Cream
	list.BorderSizePixel = 0
	list.Visible = false
	list.Parent = screenGui
	addCorner(list, 18)
	local listStroke = Instance.new("UIStroke")
	listStroke.Color = palette.Gold
	listStroke.Thickness = 3
	listStroke.Parent = list
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = list
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local function addButton(label: string, destination: string, order: number)
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, 0, 0, 52)
		button.LayoutOrder = order
		button.BackgroundColor3 = Color3.fromRGB(255, 250, 235)
		button.Font = Enum.Font.GothamBold
		button.Text = label
		button.TextColor3 = palette.Ink
		button.TextSize = 22
		button.Parent = list
		addCorner(button, 14)
		button.Activated:Connect(function()
			list.Visible = false
			event:FireServer(destination)
		end)
	end

	local function rebuild()
		for _, child in list:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		addButton("입구", "Entrance", 1)
		for index, zone in GameConfig.ZoneOrder do
			if park:GetAttribute("Zone_" .. zone) == true then
				addButton(GameConfig.ZoneNames[zone], zone, 1 + index)
			end
		end
	end

	for _, zone in GameConfig.ZoneOrder do
		park:GetAttributeChangedSignal("Zone_" .. zone):Connect(rebuild)
	end
	toggle.Activated:Connect(function()
		list.Visible = not list.Visible
	end)
	rebuild()
end

return TravelController
