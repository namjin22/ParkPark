--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ParkParkHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local ticketLabel = Instance.new("TextLabel")
ticketLabel.Name = "TicketCount"
ticketLabel.AnchorPoint = Vector2.new(0, 0)
ticketLabel.Position = UDim2.fromOffset(20, 20)
ticketLabel.Size = UDim2.fromOffset(220, 52)
ticketLabel.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
ticketLabel.BackgroundTransparency = 0.15
ticketLabel.BorderSizePixel = 0
ticketLabel.Font = Enum.Font.GothamBold
ticketLabel.TextColor3 = Color3.fromRGB(255, 245, 205)
ticketLabel.TextScaled = true
ticketLabel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = ticketLabel

local leaderstats = player:WaitForChild("leaderstats")
local tickets = leaderstats:WaitForChild("Tickets") :: IntValue

local function updateTicketDisplay()
	ticketLabel.Text = string.format("%s: %d", GameConfig.TicketDisplayName, tickets.Value)
end

updateTicketDisplay()
tickets:GetPropertyChangedSignal("Value"):Connect(updateTicketDisplay)

print("[ParkPark] Client bootstrap loaded")
