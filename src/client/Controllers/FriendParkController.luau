--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local UITheme = require(Config:WaitForChild("UITheme"))

-- A "친구 공원" button opens a small panel: invite a friend (the Roblox invite dialog carries your user id, so the
-- friend lands in your park), visit a friend who is playing right now, or go back to your own park. A line at the
-- top says whose park you are in when it is not yours. Visits are validated by the server (friends only).
local FriendParkController = {}

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function FriendParkController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local events = ReplicatedStorage:WaitForChild("ParkParkEvents")
	local requestList = events:WaitForChild("RequestFriendParks") :: RemoteEvent
	local listRemote = events:WaitForChild("FriendParks") :: RemoteEvent
	local visitRemote = events:WaitForChild("VisitPark") :: RemoteEvent
	local park = Workspace:WaitForChild("ParkParkWorld")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ParkParkFriends"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 12
	screenGui.Parent = playerGui

	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.fromOffset(72, 44)
	toggle.BackgroundColor3 = UITheme.Button
	toggle.Font = Enum.Font.GothamBold
	toggle.Text = "친구 공원"
	toggle.TextColor3 = UITheme.Text
	toggle.TextSize = 15
	toggle.Parent = screenGui
	addCorner(toggle, 16)
	local stroke = Instance.new("UIStroke")
	stroke.Color = UITheme.Border
	stroke.Thickness = 1
	stroke.Parent = toggle

	local banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 6)
	banner.Size = UDim2.fromOffset(240, 26)
	banner.BackgroundColor3 = UITheme.Panel
	banner.BorderSizePixel = 0
	banner.Font = Enum.Font.GothamBold
	banner.TextColor3 = UITheme.Text
	banner.TextSize = 14
	banner.Visible = false
	banner.Parent = screenGui
	addCorner(banner, 8)

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(260, 0)
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
			toggle.Position = UDim2.new(1, -12, 0.54, 208)
			panel.AnchorPoint = Vector2.new(1, 0.5)
			panel.Position = UDim2.new(1, -92, 0.5, 0)
		else
			toggle.AnchorPoint = Vector2.new(0, 0)
			toggle.Position = UDim2.fromOffset(304, 150)
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

	local function makeButton(text: string, order: number): TextButton
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, 0, 0, 36)
		button.LayoutOrder = order
		button.BackgroundColor3 = UITheme.Button
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamMedium
		button.Text = text
		button.TextColor3 = UITheme.Text
		button.TextSize = 14
		button.Parent = panel
		addCorner(button, 8)
		return button
	end

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 20)
	title.LayoutOrder = 0
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "친구 공원"
	title.TextColor3 = UITheme.Muted
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local invite = makeButton("친구 초대", 1)
	invite.Activated:Connect(function()
		pcall(function()
			if SocialService:CanSendGameInviteAsync(player) then
				local options = Instance.new("ExperienceInviteOptions")
				options.LaunchData = tostring(player.UserId)
				options.PromptMessage = "내 공원에 놀러 오세요"
				SocialService:PromptGameInvite(player, options)
			end
		end)
	end)

	local home = makeButton("내 공원으로", 2)
	home.Visible = false
	home.Activated:Connect(function()
		visitRemote:FireServer(player.UserId)
	end)

	local rows: { TextButton } = {}
	local function clearRows()
		for _, row in rows do
			row:Destroy()
		end
		table.clear(rows)
	end

	listRemote.OnClientEvent:Connect(function(list: unknown, _ownerName: unknown, isVisitor: unknown)
		clearRows()
		home.Visible = isVisitor == true
		if type(list) ~= "table" then
			return
		end
		local order = 10
		local entries: { any } = list :: any
		for _, entry in entries do
			if type(entry) == "table" and type(entry.userId) == "number" and type(entry.name) == "string" then
				order += 1
				local row = makeButton(entry.name .. " 공원 방문", order)
				local userId = entry.userId
				row.Activated:Connect(function()
					visitRemote:FireServer(userId)
				end)
				table.insert(rows, row)
			end
		end
		if #rows == 0 then
			local empty = makeButton("지금 접속 중인 친구가 없어요", 10)
			empty.Active = false
			empty.TextColor3 = UITheme.Muted
			table.insert(rows, empty)
		end
	end)

	local function refreshBanner()
		local visitor = player:GetAttribute("IsVisitor") == true
		local owner = park:GetAttribute("OwnerName")
		banner.Visible = visitor and type(owner) == "string" and owner ~= ""
		if banner.Visible then
			banner.Text = string.format("%s의 공원 방문 중", owner :: string)
		end
		home.Visible = visitor
	end
	player:GetAttributeChangedSignal("IsVisitor"):Connect(refreshBanner)
	park:GetAttributeChangedSignal("OwnerName"):Connect(refreshBanner)
	refreshBanner()

	playerGui:GetAttributeChangedSignal("OpenPanel"):Connect(function()
		if playerGui:GetAttribute("OpenPanel") ~= "Friends" then
			panel.Visible = false
		end
	end)
	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		playerGui:SetAttribute("OpenPanel", if panel.Visible then "Friends" else "")
		if panel.Visible then
			requestList:FireServer()
		end
	end)
end

return FriendParkController
