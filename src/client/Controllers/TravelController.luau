--!strict

local UITheme = require(
	game:GetService("ReplicatedStorage"):WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("UITheme")
)
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
	corner.CornerRadius = UDim.new(0, math.clamp(math.floor(radius / 2), 4, 10))
	corner.Parent = parent
end

function TravelController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local park = Workspace:WaitForChild("ParkParkWorld")
	local event = ReplicatedStorage:WaitForChild("ParkParkEvents"):WaitForChild("Travel") :: RemoteEvent

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ParkParkTravel"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 12
	screenGui.Parent = playerGui

	local toggle = UITheme.MenuButton("이동", screenGui)

	local list = Instance.new("Frame")
	list.Size = UDim2.fromOffset(168, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.BackgroundColor3 = UITheme.Panel
	list.BorderSizePixel = 0
	list.Visible = false
	list.Parent = screenGui
	addCorner(list, 18)
	local listStroke = Instance.new("UIStroke")
	listStroke.Color = UITheme.Border
	listStroke.Thickness = 1
	listStroke.Parent = list
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = list
	-- Two columns: with every zone open the list has thirteen places, too tall for a phone held sideways.
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(76, 28)
	layout.CellPadding = UDim2.fromOffset(4, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- The shared menu strip (UITheme.MenuSlot): first slot; the list opens where every menu panel opens.
	local function updateLayout()
		local camera = Workspace.CurrentCamera
		local portrait = camera ~= nil and UITheme.IsPortrait(camera.ViewportSize)
		toggle.AnchorPoint, toggle.Position = UITheme.MenuSlot(1, portrait)
		list.AnchorPoint, list.Position = UITheme.MenuPanel(portrait)
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

	local function addButton(label: string, destination: string, order: number)
		local button = Instance.new("TextButton")
		button.LayoutOrder = order
		button.BackgroundColor3 = UITheme.Button
		button.Font = Enum.Font.GothamBold
		button.Text = label
		button.TextColor3 = UITheme.Text
		button.TextSize = 12
		button.TextWrapped = true
		button.Parent = list
		addCorner(button, 10)
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
	playerGui:GetAttributeChangedSignal("OpenPanel"):Connect(function()
		if playerGui:GetAttribute("OpenPanel") ~= "Travel" then
			list.Visible = false
		end
	end)
	toggle.Activated:Connect(function()
		list.Visible = not list.Visible
		playerGui:SetAttribute("OpenPanel", if list.Visible then "Travel" else "")
	end)
	rebuild()
end

return TravelController
