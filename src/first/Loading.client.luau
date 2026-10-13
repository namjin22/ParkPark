--!strict

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- A plain loading screen: the game's name on a cream background until the world is ready (the park folder exists
-- and the game has loaded), at least a moment so it never flashes, and at most a short while so it can never get
-- stuck. Korean for Korean players, English for everyone else.
ReplicatedFirst:RemoveDefaultLoadingScreen()

local MINIMUM_SECONDS = 1.5
local MAXIMUM_SECONDS = 25

local player = Players.LocalPlayer
local korean = string.sub(string.lower(player.LocaleId), 1, 2) == "ko"
local started = os.clock()

local playerGui = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "ParkParkLoading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.Parent = playerGui

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(250, 247, 239)
background.BorderSizePixel = 0
background.Parent = gui

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.45)
title.Size = UDim2.fromOffset(420, 70)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.Text = "PARK PARK"
title.TextColor3 = Color3.fromRGB(46, 52, 56)
title.TextSize = 54
title.Parent = background

local subtitle = Instance.new("TextLabel")
subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
subtitle.Position = UDim2.fromScale(0.5, 0.55)
subtitle.Size = UDim2.fromOffset(420, 30)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.GothamMedium
subtitle.Text = if korean then "공원을 불러오는 중이에요" else "Loading your park"
subtitle.TextColor3 = Color3.fromRGB(110, 116, 120)
subtitle.TextSize = 20
subtitle.Parent = background

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 0.5)
bar.Position = UDim2.fromScale(0.5, 0.62)
bar.Size = UDim2.fromOffset(220, 4)
bar.BackgroundColor3 = Color3.fromRGB(224, 220, 210)
bar.BorderSizePixel = 0
bar.Parent = background
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0.15, 1)
fill.BackgroundColor3 = Color3.fromRGB(76, 150, 120)
fill.BorderSizePixel = 0
fill.Parent = bar

-- A looping sweep so it is clear that something is happening.
task.spawn(function()
	while gui.Parent ~= nil do
		fill.Position = UDim2.fromScale(-0.15, 0)
		local tween =
			TweenService:Create(fill, TweenInfo.new(1.1, Enum.EasingStyle.Sine), { Position = UDim2.fromScale(1, 0) })
		tween:Play()
		tween.Completed:Wait()
	end
end)

local function ready(): boolean
	return game:IsLoaded() and Workspace:FindFirstChild("ParkParkWorld") ~= nil
end

while os.clock() - started < MAXIMUM_SECONDS and (os.clock() - started < MINIMUM_SECONDS or not ready()) do
	task.wait(0.1)
end

local fade = TweenInfo.new(0.5)
TweenService:Create(background, fade, { BackgroundTransparency = 1 }):Play()
for _, label in { title, subtitle } do
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
end
TweenService:Create(bar, fade, { BackgroundTransparency = 1 }):Play()
TweenService:Create(fill, fade, { BackgroundTransparency = 1 }):Play()
task.wait(0.6)
gui:Destroy()
