--!strict

local UITheme = require(
	game:GetService("ReplicatedStorage"):WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("UITheme")
)
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- A round "꾸미기" button (under the travel button) opens the closet: walk trails and name titles to buy with
-- coins, then equip or take off. Everything is decided on the server; this panel only shows the state.
local ClosetController = {}

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.clamp(math.floor(radius / 2), 4, 10))
	corner.Parent = parent
end

function ClosetController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local remote = ReplicatedStorage:WaitForChild("ParkParkEvents"):WaitForChild("Closet") :: RemoteEvent

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ParkParkCloset"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 12
	screenGui.Parent = playerGui

	local toggle = Instance.new("TextButton")
	toggle.AnchorPoint = Vector2.new(1, 0.5)
	toggle.Size = UDim2.fromOffset(64, 44)
	toggle.BackgroundColor3 = UITheme.Button
	toggle.Font = Enum.Font.GothamBold
	toggle.Text = "꾸미기"
	toggle.TextColor3 = UITheme.Text
	toggle.TextSize = 16
	toggle.Parent = screenGui
	addCorner(toggle, 36)
	local stroke = Instance.new("UIStroke")
	stroke.Color = UITheme.Border
	stroke.Thickness = 1
	stroke.Parent = toggle

	local panel = Instance.new("ScrollingFrame")
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Size = UDim2.fromOffset(250, 300)
	panel.CanvasSize = UDim2.fromOffset(0, 0)
	panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	panel.ScrollBarThickness = 4
	panel.ScrollingDirection = Enum.ScrollingDirection.Y
	panel.BackgroundColor3 = UITheme.Panel
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = screenGui
	addCorner(panel, 18)
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = UITheme.Border
	panelStroke.Thickness = 1
	panelStroke.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
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
		local y = if compactPortrait then 0.54 else 0.42
		toggle.Position = UDim2.new(1, -12, y, 52)
		panel.Position = UDim2.new(1, -84, 0.5, 0)
		local viewport = if camera then camera.ViewportSize.Y else 600
		panel.Size = UDim2.fromOffset(
			if compactPortrait then 230 else 250,
			math.clamp(layout.AbsoluteContentSize.Y + 16, 80, math.max(120, viewport - 120))
		)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateLayout)
	local function bindCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
		end
		updateLayout()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()

	local function header(text: string, order: number)
		local label = Instance.new("TextLabel")
		label.Name = "Header"
		label.Size = UDim2.new(1, 0, 0, 22)
		label.LayoutOrder = order
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.Text = text
		label.TextColor3 = UITheme.Muted
		label.TextSize = 14
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = panel
	end

	local function ownedSet(): { [string]: boolean }
		local set = {}
		for id in string.gmatch((player:GetAttribute("Owned") :: string?) or "", "[^,]+") do
			set[id] = true
		end
		return set
	end

	local function rebuild()
		for _, child in panel:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local owned = ownedSet()
		local trail = (player:GetAttribute("Trail") :: string?) or ""
		local title = (player:GetAttribute("Title") :: string?) or ""
		local order = 0
		local lastKind = ""
		for _, item in GameConfig.Cosmetics do
			if item.Kind ~= lastKind then
				lastKind = item.Kind
				order += 1
				header(if item.Kind == "Trail" then "이동 효과" else "이름표", order)
			end
			order += 1
			local row = Instance.new("TextButton")
			row.Name = item.Id
			row.Size = UDim2.new(1, 0, 0, 38)
			row.LayoutOrder = order
			row.Font = Enum.Font.GothamBold
			row.TextSize = 15
			row.TextColor3 = UITheme.Text
			row.Parent = panel
			addCorner(row, 12)
			local isOwned = owned[item.Id] == true
			local isOn = item.Id == trail or item.Id == title
			if isOwned then
				row.BackgroundColor3 = if isOn then UITheme.ButtonOn else UITheme.Button
				row.Text = string.format("%s  (%s)", item.Name, if isOn then "착용 중 · 해제" else "착용")
				row.Activated:Connect(function()
					remote:FireServer(if isOn then "Unequip" else "Equip", item.Id)
				end)
			elseif item.PassOnly then
				row.BackgroundColor3 = UITheme.Button
				row.TextColor3 = UITheme.Muted
				row.Text = item.Name .. "  (후원자 전용)"
				row.Activated:Connect(function()
					if GameConfig.Monetization.PassId > 0 then
						MarketplaceService:PromptGamePassPurchase(player, GameConfig.Monetization.PassId)
					end
				end)
			else
				row.BackgroundColor3 = UITheme.Button
				row.Text = string.format("%s  %d코인", item.Name, item.Cost)
				row.Activated:Connect(function()
					remote:FireServer("Buy", item.Id)
				end)
			end
		end
	end
	for _, name in { "Owned", "Trail", "Title" } do
		player:GetAttributeChangedSignal(name):Connect(rebuild)
	end
	rebuild()

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
end

return ClosetController
