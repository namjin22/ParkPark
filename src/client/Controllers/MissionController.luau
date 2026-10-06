--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local UITheme = require(Config:WaitForChild("UITheme"))

-- A "미션" button next to the travel and closet buttons opens today's three missions with their progress and
-- rewards. The server publishes them as `Mission1..3` on the player ("text|progress|goal|reward|done").
local MissionController = {}

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function MissionController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ParkParkMissions"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 12
	screenGui.Parent = playerGui

	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.fromOffset(64, 44)
	toggle.BackgroundColor3 = UITheme.Button
	toggle.Font = Enum.Font.GothamBold
	toggle.Text = "미션"
	toggle.TextColor3 = UITheme.Text
	toggle.TextSize = 16
	toggle.Parent = screenGui
	addCorner(toggle, 16)
	local stroke = Instance.new("UIStroke")
	stroke.Color = UITheme.Border
	stroke.Thickness = 1
	stroke.Parent = toggle

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(250, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = UITheme.Panel
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = screenGui
	addCorner(panel, 12)
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = UITheme.Border
	panelStroke.Thickness = 1
	panelStroke.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local function updateLayout()
		local camera = Workspace.CurrentCamera
		local compactPortrait = camera ~= nil
			and camera.ViewportSize.X < 550
			and camera.ViewportSize.Y > camera.ViewportSize.X
		if compactPortrait then
			toggle.AnchorPoint = Vector2.new(1, 0.5)
			toggle.Position = UDim2.new(1, -12, 0.54, 104)
			panel.AnchorPoint = Vector2.new(1, 0.5)
			panel.Position = UDim2.new(1, -84, 0.5, 0)
		else
			toggle.AnchorPoint = Vector2.new(0, 0)
			toggle.Position = UDim2.fromOffset(160, 150)
			panel.AnchorPoint = Vector2.new(0, 0)
			panel.Position = UDim2.fromOffset(16, 198)
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

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 20)
	title.LayoutOrder = 0
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "오늘의 미션"
	title.TextColor3 = UITheme.Muted
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local rows: { TextLabel } = {}
	for index = 1, 3 do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 38)
		row.LayoutOrder = index
		row.BackgroundColor3 = UITheme.Button
		row.BorderSizePixel = 0
		row.Font = Enum.Font.GothamMedium
		row.TextSize = 13
		row.TextColor3 = UITheme.Text
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = ""
		row.Parent = panel
		addCorner(row, 8)
		local rowPadding = Instance.new("UIPadding")
		rowPadding.PaddingLeft = UDim.new(0, 8)
		rowPadding.PaddingRight = UDim.new(0, 8)
		rowPadding.Parent = row
		rows[index] = row
	end

	local function refresh()
		for index, row in rows do
			local raw = player:GetAttribute("Mission" .. index)
			if type(raw) == "string" then
				local text, shown, goal, reward, done = string.match(raw, "^(.-)|(%d+)|(%d+)|(%d+)|(%d)$")
				if text and shown and goal and reward then
					local state = if done == "1" then "완료" else string.format("%s/%s", shown, goal)
					row.Text = string.format("%s\n%s · +%s %s", text, state, reward, GameConfig.CurrencyDisplayName)
					row.BackgroundColor3 = if done == "1" then UITheme.ButtonOn else UITheme.Button
				end
			end
		end
	end
	for index = 1, 3 do
		player:GetAttributeChangedSignal("Mission" .. index):Connect(refresh)
	end
	refresh()

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
end

return MissionController
