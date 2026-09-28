--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local RepairFeedbackController = {}

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function RepairFeedbackController.Start()
	local park = Workspace:WaitForChild("ParkParkWorld")
	local carousel = park:WaitForChild("BrokenCarousel")
	if not carousel:IsA("Model") or carousel:GetAttribute("IsRepaired") == true then
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ParkParkRepairFeedback"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 11
	screenGui.Parent = playerGui

	local card = Instance.new("Frame")
	card.Name = "RepairToast"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 78)
	card.Size = UDim2.new(0.84, 0, 0, 72)
	card.BackgroundColor3 = GameConfig.Palette.Cream
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.Visible = false
	card.Parent = screenGui
	addCorner(card, 18)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(240, 72)
	sizeConstraint.MaxSize = Vector2.new(340, 72)
	sizeConstraint.Parent = card

	local outline = Instance.new("UIStroke")
	outline.Color = GameConfig.Palette.Gold
	outline.Thickness = 1.5
	outline.Transparency = 1
	outline.Parent = card

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Position = UDim2.fromOffset(0, 12)
	accent.Size = UDim2.fromOffset(6, 48)
	accent.BackgroundColor3 = GameConfig.Palette.Coral
	accent.BackgroundTransparency = 1
	accent.BorderSizePixel = 0
	accent.Parent = card
	addCorner(accent, 3)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(20, 13)
	title.Size = UDim2.new(1, -34, 0, 22)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "회전목마 복구 완료!"
	title.TextColor3 = GameConfig.Palette.Ink
	title.TextSize = 17
	title.TextTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card

	local reward = Instance.new("TextLabel")
	reward.Name = "Reward"
	reward.Position = UDim2.fromOffset(20, 38)
	reward.Size = UDim2.new(1, -34, 0, 18)
	reward.BackgroundTransparency = 1
	reward.Font = Enum.Font.GothamMedium
	reward.Text = string.format("+%d %s", GameConfig.CarouselRepairReward, GameConfig.TicketDisplayName)
	reward.TextColor3 = GameConfig.Palette.Ink
	reward.TextSize = 13
	reward.TextTransparency = 1
	reward.TextXAlignment = Enum.TextXAlignment.Left
	reward.Parent = card

	local shown = false
	local function showRepairToast()
		if shown then
			return
		end
		shown = true
		card.Visible = true
		card.Position = UDim2.new(0.5, 0, 0, 66)

		TweenService:Create(card, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0, 78),
			BackgroundTransparency = 0,
		}):Play()
		TweenService:Create(outline, TweenInfo.new(0.2), { Transparency = 0.15 }):Play()
		TweenService:Create(accent, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
		TweenService:Create(title, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
		TweenService:Create(reward, TweenInfo.new(0.2), { TextTransparency = 0.12 }):Play()

		task.delay(3, function()
			if not card.Parent then
				return
			end

			TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0, 66),
				BackgroundTransparency = 1,
			}):Play()
			TweenService:Create(outline, TweenInfo.new(0.16), { Transparency = 1 }):Play()
			TweenService:Create(accent, TweenInfo.new(0.16), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(title, TweenInfo.new(0.16), { TextTransparency = 1 }):Play()
			TweenService:Create(reward, TweenInfo.new(0.16), { TextTransparency = 1 }):Play()
			task.delay(0.22, function()
				if card.Parent then
					card.Visible = false
				end
			end)
		end)
	end

	carousel:GetAttributeChangedSignal("IsRepaired"):Connect(function()
		if carousel:GetAttribute("IsRepaired") == true then
			showRepairToast()
		end
	end)

	if carousel:GetAttribute("IsRepaired") == true then
		showRepairToast()
	end
end

return RepairFeedbackController
