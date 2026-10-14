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

	local toggle = UITheme.MenuButton("꾸미기", screenGui)

	local panel = Instance.new("ScrollingFrame")
	panel.Size = UDim2.fromOffset(220, 260)
	panel.CanvasSize = UDim2.fromOffset(0, 0)
	panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	panel.ScrollBarThickness = 4
	panel.ScrollingDirection = Enum.ScrollingDirection.Y
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
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local function updateLayout()
		local camera = Workspace.CurrentCamera
		local compactPortrait = camera ~= nil and UITheme.IsPortrait(camera.ViewportSize)
		toggle.AnchorPoint, toggle.Position = UITheme.MenuSlot(2, compactPortrait)
		panel.AnchorPoint, panel.Position = UITheme.MenuPanel(compactPortrait)
		local room = UITheme.MenuPanelRoom(screenGui, compactPortrait)
		panel.Size = UDim2.fromOffset(
			if compactPortrait then 200 else 220,
			math.clamp(layout.AbsoluteContentSize.Y + 12, 80, math.max(120, room))
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
		label.Size = UDim2.new(1, 0, 0, 18)
		label.LayoutOrder = order
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.Text = text
		label.TextColor3 = UITheme.Muted
		label.TextSize = 12
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = panel
	end

	local park = workspace:FindFirstChild("ParkParkWorld")
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
			row.Size = UDim2.new(1, 0, 0, 30)
			row.LayoutOrder = order
			row.Font = Enum.Font.GothamBold
			row.TextSize = 12
			row.TextColor3 = UITheme.Text
			row.Parent = panel
			addCorner(row, 10)
			local isOwned = owned[item.Id] == true
			local isOn = item.Id == trail or item.Id == title
			if isOwned then
				row.BackgroundColor3 = if isOn then UITheme.ButtonOn else UITheme.Button
				row.Text = string.format("%s  (%s)", item.Name, if isOn then "착용 중 · 해제" else "착용")
				row.Activated:Connect(function()
					remote:FireServer(if isOn then "Unequip" else "Equip", item.Id)
				end)
			elseif item.Season and (park == nil or park:GetAttribute("Season") ~= item.Season) then
				row.BackgroundColor3 = UITheme.Button
				row.TextColor3 = UITheme.Muted
				row.Text = item.Name .. "  (계절 한정)"
			elseif item.BookOnly then
				row.BackgroundColor3 = UITheme.Button
				row.TextColor3 = UITheme.Muted
				row.Text = item.Name .. "  (도감·업적 보상)"
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
	if park then
		park:GetAttributeChangedSignal("Season"):Connect(rebuild)
	end
	rebuild()

	-- One menu panel at a time (shared with the other menu panels through the PlayerGui attribute).
	playerGui:GetAttributeChangedSignal("OpenPanel"):Connect(function()
		if playerGui:GetAttribute("OpenPanel") ~= "Closet" then
			panel.Visible = false
		end
	end)
	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		playerGui:SetAttribute("OpenPanel", if panel.Visible then "Closet" else "")
	end)
end

return ClosetController
