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

	local toggle = UITheme.MenuButton("미션", screenGui)

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(220, 0)
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
		local compactPortrait = camera ~= nil and UITheme.IsPortrait(camera.ViewportSize)
		toggle.AnchorPoint, toggle.Position = UITheme.MenuSlot(3, compactPortrait)
		panel.AnchorPoint, panel.Position = UITheme.MenuPanel(compactPortrait)
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
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, 0, 0, 280)
	list.LayoutOrder = 1
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list
	local function fitList()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		-- The list gets what is left under the panel's title and padding.
		local room = UITheme.MenuPanelRoom(screenGui, UITheme.IsPortrait(camera.ViewportSize)) - 44
		list.Size = UDim2.new(1, 0, 0, math.clamp(room, 90, 280))
	end
	fitList()
	local fitCamera = Workspace.CurrentCamera
	if fitCamera then
		fitCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitList)
	end
	-- Recomputed on opening as well: the screen scale is added after the panel is built.
	panel:GetPropertyChangedSignal("Visible"):Connect(fitList)

	local function makeRow(order: number): TextLabel
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -8, 0, 32)
		row.LayoutOrder = order
		row.BackgroundColor3 = UITheme.Button
		row.BorderSizePixel = 0
		row.Font = Enum.Font.GothamMedium
		row.TextSize = 12
		row.TextColor3 = UITheme.Text
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = ""
		row.Parent = list
		addCorner(row, 8)
		local rowPadding = Instance.new("UIPadding")
		rowPadding.PaddingLeft = UDim.new(0, 8)
		rowPadding.PaddingRight = UDim.new(0, 8)
		rowPadding.Parent = row
		return row
	end

	local DAILY = 3
	local WEEKLY = #GameConfig.WeeklyOrder
	local dailyRows: { TextLabel } = {}
	for index = 1, DAILY do
		dailyRows[index] = makeRow(index)
	end
	local weeklyHeader = Instance.new("TextLabel")
	weeklyHeader.Size = UDim2.new(1, -8, 0, 20)
	weeklyHeader.LayoutOrder = 10
	weeklyHeader.BackgroundTransparency = 1
	weeklyHeader.Font = Enum.Font.GothamBold
	weeklyHeader.Text = "이번 주 목표"
	weeklyHeader.TextColor3 = UITheme.Muted
	weeklyHeader.TextSize = 12
	weeklyHeader.TextXAlignment = Enum.TextXAlignment.Left
	weeklyHeader.Parent = list
	local weeklyRows: { TextLabel } = {}
	for index = 1, WEEKLY do
		weeklyRows[index] = makeRow(10 + index)
	end

	local function show(row: TextLabel, raw: unknown)
		if type(raw) ~= "string" then
			return
		end
		local text, shown, goal, reward, done = string.match(raw, "^(.-)|(%d+)|(%d+)|(%d+)|(%d)$")
		if text and shown and goal and reward then
			local state = if done == "1" then "완료" else string.format("%s/%s", shown, goal)
			row.Text = string.format("%s\n%s · +%s %s", text, state, reward, GameConfig.CurrencyDisplayName)
			row.BackgroundColor3 = if done == "1" then UITheme.ButtonOn else UITheme.Button
		end
	end
	local function refresh()
		for index, row in dailyRows do
			show(row, player:GetAttribute("Mission" .. index))
		end
		for index, row in weeklyRows do
			show(row, player:GetAttribute("Weekly" .. index))
		end
	end
	for index = 1, DAILY do
		player:GetAttributeChangedSignal("Mission" .. index):Connect(refresh)
	end
	for index = 1, WEEKLY do
		player:GetAttributeChangedSignal("Weekly" .. index):Connect(refresh)
	end
	refresh()

	-- Only one of the side panels (missions, book) is open at a time.
	playerGui:GetAttributeChangedSignal("OpenPanel"):Connect(function()
		if playerGui:GetAttribute("OpenPanel") ~= "Missions" then
			panel.Visible = false
		end
	end)
	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		playerGui:SetAttribute("OpenPanel", if panel.Visible then "Missions" else "")
	end)
end

return MissionController
