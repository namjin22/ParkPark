--!strict

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- One panel for everything a player does at an attraction's console: unlock, repair, raise the fare, hire
-- staff. Standing at a console and pressing its single "관리" prompt (a tap on touch screens) opens it, and
-- it shows only what applies right now, with big buttons. The server validates every action itself; this
-- only sends (ride key, action) and shows the attributes the server publishes on the ride model.
local ManagePanelController = {}

local CLOSE_DISTANCE = 30
local PANEL_WIDTH = 460
local PANEL_MAX_HEIGHT = 480

local ACTION_ROWS = { "Unlock", "Repair", "Income", "Staff" }

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function makeLabel(parent: Instance, size: number, bold: boolean, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	label.TextSize = size
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent
	return label
end

function ManagePanelController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local park = Workspace:WaitForChild("ParkParkWorld")
	local actionEvent = ReplicatedStorage:WaitForChild("ParkParkEvents"):WaitForChild("RideAction") :: RemoteEvent
	local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins") :: IntValue
	local currency = GameConfig.CurrencyDisplayName
	local palette = GameConfig.Palette

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ParkParkManage"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 20
	screenGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -20)
	panel.Size = UDim2.new(0.94, 0, 0, PANEL_MAX_HEIGHT)
	panel.BackgroundColor3 = palette.Cream
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = screenGui
	addCorner(panel, 22)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(PANEL_WIDTH, PANEL_MAX_HEIGHT)
	limit.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = palette.Gold
	stroke.Thickness = 3
	stroke.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	-- Keep the title and close button on-screen on short landscape phones; action rows scroll inside the panel.
	local actionList = Instance.new("ScrollingFrame")
	actionList.Name = "Actions"
	actionList.BackgroundTransparency = 1
	actionList.BorderSizePixel = 0
	actionList.Size = UDim2.new(1, 0, 1, -(64 + layout.Padding.Offset))
	actionList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	actionList.CanvasSize = UDim2.new(0, 0, 0, 0)
	actionList.ScrollingDirection = Enum.ScrollingDirection.Y
	actionList.ScrollBarThickness = 4
	actionList.ScrollBarImageColor3 = palette.Gold
	actionList.LayoutOrder = 2
	actionList.Parent = panel
	local actionLayout = Instance.new("UIListLayout")
	actionLayout.Padding = UDim.new(0, 10)
	actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actionLayout.Parent = actionList

	local visibleActionCount = 0
	local boundCamera: Camera? = nil
	local function updatePanelSize()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local availableHeight = math.max(120, camera.ViewportSize.Y - 40)
		local rowsHeight = visibleActionCount * 76 + math.max(0, visibleActionCount - 1) * actionLayout.Padding.Offset
		local contentHeight = 104 + rowsHeight
		panel.Size = UDim2.new(0.94, 0, 0, math.min(PANEL_MAX_HEIGHT, availableHeight, contentHeight))
	end
	local function bindCamera()
		local camera = Workspace.CurrentCamera
		if camera == boundCamera then
			return
		end
		boundCamera = camera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(updatePanelSize)
		end
		updatePanelSize()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()

	-- Header: the ride's name, its state, and a close button.
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 64)
	header.LayoutOrder = 1
	header.Parent = panel
	local titleLabel = makeLabel(header, 30, true, palette.Ink)
	titleLabel.Size = UDim2.new(1, -110, 0, 36)
	local statusLabel = makeLabel(header, 20, false, palette.Ink)
	statusLabel.Position = UDim2.fromOffset(0, 38)
	statusLabel.Size = UDim2.new(1, -110, 0, 26)
	local closeButton = Instance.new("TextButton")
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.fromScale(1, 0)
	closeButton.Size = UDim2.fromOffset(96, 48)
	closeButton.BackgroundColor3 = palette.Ink
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Text = "닫기"
	closeButton.TextColor3 = palette.Cream
	closeButton.TextSize = 22
	closeButton.Parent = header
	addCorner(closeButton, 14)

	-- One row per action: what it does, and a big button with its price.
	type Row = { frame: Frame, title: TextLabel, detail: TextLabel, button: TextButton }
	local rows: { [string]: Row } = {}
	for index, action in ACTION_ROWS do
		local frame = Instance.new("Frame")
		frame.Name = action
		frame.BackgroundColor3 = Color3.fromRGB(255, 250, 235)
		frame.BorderSizePixel = 0
		frame.Size = UDim2.new(1, 0, 0, 76)
		frame.LayoutOrder = index
		frame.Visible = false
		frame.Parent = actionList
		addCorner(frame, 16)
		local rowStroke = Instance.new("UIStroke")
		rowStroke.Color = palette.Gold
		rowStroke.Transparency = 0.5
		rowStroke.Thickness = 1.5
		rowStroke.Parent = frame

		local title = makeLabel(frame, 23, true, palette.Ink)
		title.Position = UDim2.fromOffset(14, 8)
		title.Size = UDim2.new(1, -170, 0, 30)
		local detail = makeLabel(frame, 18, false, palette.Ink)
		detail.Position = UDim2.fromOffset(14, 40)
		detail.Size = UDim2.new(1, -170, 0, 28)

		local button = Instance.new("TextButton")
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -10, 0.5, 0)
		button.Size = UDim2.fromOffset(142, 56)
		button.BackgroundColor3 = palette.Mint
		button.Font = Enum.Font.GothamBold
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextSize = 21
		button.Parent = frame
		addCorner(button, 14)

		rows[action] = { frame = frame, title = title, detail = detail, button = button }
	end

	local currentKey: string? = nil
	local currentConsole: BasePart? = nil

	local function rideModel(key: string): Model?
		local config = GameConfig.Rides[key]
		local model = park:FindFirstChild(config.ModelName)
		return if model and model:IsA("Model") then model else nil
	end

	local function setButton(row: Row, text: string, usable: boolean)
		row.button.Text = text
		row.button.BackgroundColor3 = if usable then palette.Mint else Color3.fromRGB(176, 170, 156)
		row.button.AutoButtonColor = usable
	end

	local function refresh()
		local key = currentKey
		if key == nil then
			return
		end
		local model = rideModel(key)
		if model == nil then
			return
		end
		local config = GameConfig.Rides[key]
		local unlocked = model:GetAttribute("IsUnlocked") == true
		local repaired = model:GetAttribute("IsRepaired") == true
		local blocked = (model:GetAttribute("BlockedReason") :: string?) or ""
		local balance = coins.Value
		local noun = if config.IsShop == true then "서빙" else "탑승"

		titleLabel.Text = config.DisplayName
		if not unlocked then
			statusLabel.Text = if blocked ~= "" then blocked else "아직 잠겨 있어요"
		elseif not repaired then
			statusLabel.Text = "고장 났어요 · 고치면 손님이 와요"
		else
			local queue = (model:GetAttribute("QueueLength") :: number?) or 0
			statusLabel.Text = string.format(
				"손님당 +%d %s · 대기 %d/%d",
				(model:GetAttribute("Fare") :: number?) or config.BaseFare,
				currency,
				queue,
				GameConfig.QueueMax
			)
		end

		local unlockRow = rows.Unlock
		unlockRow.frame.Visible = not unlocked and config.UnlockCost > 0
		unlockRow.title.Text = "해금하기"
		unlockRow.detail.Text = if blocked ~= ""
			then blocked
			else string.format("손님당 +%d %s 수입", config.BaseFare, currency)
		setButton(
			unlockRow,
			if blocked ~= "" then "잠김" else string.format("%d %s", config.UnlockCost, currency),
			blocked == "" and balance >= config.UnlockCost
		)

		local repairRow = rows.Repair
		repairRow.frame.Visible = unlocked and not repaired
		repairRow.title.Text = "수리하기"
		repairRow.detail.Text = if blocked ~= "" then blocked else "고치면 바로 운행해요"
		setButton(
			repairRow,
			if blocked ~= "" then "잠김" else string.format("%d %s", config.RepairCost, currency),
			blocked == "" and balance >= config.RepairCost
		)

		local incomeRow = rows.Income
		incomeRow.frame.Visible = repaired
		local incomeLevel = (model:GetAttribute("IncomeLevel") :: number?) or 0
		local incomeCost = config.IncomeCosts[incomeLevel + 1]
		local fare = config.BaseFare + incomeLevel * config.IncomePerLevel
		incomeRow.title.Text = string.format("요금 올리기 Lv %d/%d", incomeLevel, #config.IncomeCosts)
		if incomeCost then
			incomeRow.detail.Text =
				string.format("손님당 +%d → +%d %s", fare, fare + config.IncomePerLevel, currency)
			setButton(incomeRow, string.format("%d %s", incomeCost, currency), balance >= incomeCost)
		else
			incomeRow.detail.Text = string.format("최대예요 · 손님당 +%d %s", fare, currency)
			setButton(incomeRow, "최대", false)
		end

		local staffRow = rows.Staff
		staffRow.frame.Visible = repaired
		local staffLevel = (model:GetAttribute("StaffLevel") :: number?) or 0
		local staffCost = config.StaffCosts[staffLevel + 1]
		staffRow.title.Text = string.format("직원 고용 Lv %d/%d", staffLevel, #config.StaffCosts)
		if staffCost then
			staffRow.detail.Text =
				string.format("%d초마다 자동으로 %s", GameConfig.StaffIntervals[staffLevel + 1], noun)
			setButton(staffRow, string.format("%d %s", staffCost, currency), balance >= staffCost)
		else
			staffRow.detail.Text =
				string.format("최대예요 · %d초마다 자동 %s", GameConfig.StaffIntervals[staffLevel], noun)
			setButton(staffRow, "최대", false)
		end

		visibleActionCount = 0
		for _, row in rows do
			if row.frame.Visible then
				visibleActionCount += 1
			end
		end
		updatePanelSize()
	end

	local function close()
		currentKey = nil
		currentConsole = nil
		panel.Visible = false
	end

	local function open(key: string, console: BasePart)
		if currentKey == key then
			close()
			return
		end
		currentKey = key
		currentConsole = console
		actionList.CanvasPosition = Vector2.zero
		refresh()
		panel.Visible = true
	end

	for action, row in rows do
		row.button.Activated:Connect(function()
			if currentKey then
				actionEvent:FireServer(currentKey, action)
			end
		end)
	end
	closeButton.Activated:Connect(close)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, triggeringPlayer: Player)
		if triggeringPlayer ~= player or prompt.Name ~= "ManagePrompt" then
			return
		end
		local key = prompt:GetAttribute("RideKey")
		local console = prompt.Parent
		if type(key) == "string" and console and console:IsA("BasePart") and GameConfig.Rides[key] then
			open(key, console)
		end
	end)

	-- Keep the panel current while it is open: every published attribute, the park's state, and the balance.
	for key in GameConfig.Rides do
		task.spawn(function()
			local model = park:WaitForChild(GameConfig.Rides[key].ModelName)
			for _, attribute in
				{
					"IsUnlocked",
					"IsRepaired",
					"IncomeLevel",
					"StaffLevel",
					"Fare",
					"QueueLength",
					"BlockedReason",
				}
			do
				model:GetAttributeChangedSignal(attribute):Connect(function()
					if currentKey == key then
						refresh()
					end
				end)
			end
		end)
	end
	coins:GetPropertyChangedSignal("Value"):Connect(refresh)

	-- Walking away closes it.
	task.spawn(function()
		while true do
			task.wait(0.3)
			local console = currentConsole
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if
				console
				and root
				and root:IsA("BasePart")
				and (root.Position - console.Position).Magnitude > CLOSE_DISTANCE
			then
				close()
			end
		end
	end)

	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			panel.Position = UDim2.new(0.5, 0, 1, 40)
			TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, 0, 1, -20),
			}):Play()
		end
	end)
end

return ManagePanelController
