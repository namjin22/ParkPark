--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local UITheme = require(Config:WaitForChild("UITheme"))

-- A "도감" button beside the mission button opens the collection book: one row per gathering area with the pickups
-- collected so far. The server publishes the pages as the player attribute `Book` ("key|label|count|target;...").
local BookController = {}

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function BookController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ParkParkBook"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 12
	screenGui.Parent = playerGui

	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.fromOffset(64, 44)
	toggle.BackgroundColor3 = UITheme.Button
	toggle.Font = Enum.Font.GothamBold
	toggle.Text = "도감"
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
			toggle.Position = UDim2.new(1, -12, 0.54, 156)
			panel.AnchorPoint = Vector2.new(1, 0.5)
			panel.Position = UDim2.new(1, -84, 0.5, 0)
		else
			toggle.AnchorPoint = Vector2.new(0, 0)
			toggle.Position = UDim2.fromOffset(232, 150)
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
	title.Text = string.format("도감 · 쪽마다 %d개", GameConfig.Book.PageTarget)
	title.TextColor3 = UITheme.Muted
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, 0, 0, 260)
	list.LayoutOrder = 1
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list
	local function fitList()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local view = camera.ViewportSize
		local portrait = view.X < 550 and view.Y > view.X
		local room = if portrait then view.Y * 0.5 - 40 else view.Y - 198 - 60
		list.Size = UDim2.new(1, 0, 0, math.clamp(room, 110, 260))
	end
	fitList()
	local fitCamera = Workspace.CurrentCamera
	if fitCamera then
		fitCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitList)
	end

	local rows: { [string]: TextLabel } = {}
	local function rowFor(key: string, order: number): TextLabel
		local existing = rows[key]
		if existing then
			return existing
		end
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -8, 0, 28)
		row.LayoutOrder = order
		row.BackgroundColor3 = UITheme.Button
		row.BorderSizePixel = 0
		row.Font = Enum.Font.GothamMedium
		row.TextSize = 14
		row.TextColor3 = UITheme.Text
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = ""
		row.Parent = list
		addCorner(row, 8)
		local rowPadding = Instance.new("UIPadding")
		rowPadding.PaddingLeft = UDim.new(0, 8)
		rowPadding.PaddingRight = UDim.new(0, 8)
		rowPadding.Parent = row
		rows[key] = row
		return row
	end

	local function refresh()
		local raw = player:GetAttribute("Book")
		if type(raw) ~= "string" then
			return
		end
		local order = 0
		for entry in string.gmatch(raw, "[^;]+") do
			local key, label, count, target = string.match(entry, "^(.-)|(.-)|(%d+)|(%d+)$")
			if key and label and count and target then
				order += 1
				local row = rowFor(key, order)
				local full = tonumber(count) >= tonumber(target)
				row.Text = string.format("%s  %s/%s%s", label, count, target, if full then "  완성" else "")
				row.BackgroundColor3 = if full then UITheme.ButtonOn else UITheme.Button
			end
		end
	end
	player:GetAttributeChangedSignal("Book"):Connect(refresh)
	refresh()

	-- Only one of the side panels (missions, book) is open at a time.
	playerGui:GetAttributeChangedSignal("OpenPanel"):Connect(function()
		if playerGui:GetAttribute("OpenPanel") ~= "Book" then
			panel.Visible = false
		end
	end)
	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		playerGui:SetAttribute("OpenPanel", if panel.Visible then "Book" else "")
	end)
end

return BookController
