--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local UITheme = require(Config:WaitForChild("UITheme"))

-- While the player carries a parcel (`DeliveryTo` on the player), the destination's console is outlined and a small
-- label above it, visible from far away, says where to go.
local DeliveryMarkerController = {}

function DeliveryMarkerController.Start()
	local player = Players.LocalPlayer
	local park = Workspace:WaitForChild("ParkParkWorld")
	local highlight = Instance.new("Highlight")
	highlight.Name = "DeliveryHighlight"
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 205, 80)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = player:WaitForChild("PlayerGui")

	local tag = Instance.new("BillboardGui")
	tag.Name = "DeliveryTag"
	tag.Size = UDim2.fromOffset(150, 34)
	tag.StudsOffset = Vector3.new(0, 7, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 2000
	tag.LightInfluence = 0
	tag.Enabled = false
	tag.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = UITheme.Panel
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = UITheme.Text
	label.Parent = tag
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label

	local tagLoose: any = tag
	local function refresh()
		local key = player:GetAttribute("DeliveryTo")
		local config = if type(key) == "string" then GameConfig.Rides[key] else nil
		local console = if config then park:FindFirstChild(config.ConsoleName, true) else nil
		if config and console and console:IsA("BasePart") then
			highlight.Adornee = console
			tag.Adornee = console
			label.Text = "배달: " .. config.DisplayName
			tag.Enabled = true
		else
			highlight.Adornee = nil
			tagLoose.Adornee = nil
			tag.Enabled = false
		end
	end
	player:GetAttributeChangedSignal("DeliveryTo"):Connect(refresh)
	refresh()
end

return DeliveryMarkerController
