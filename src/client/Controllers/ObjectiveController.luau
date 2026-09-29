--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- First-session guide: one objective card under the coin HUD, plus an outline on the thing to use
-- next. Steps follow the server-owned park attributes, so the guide never runs ahead of the game.
local ObjectiveController = {}

type Step = {
	title: string,
	detail: string,
	target: Instance?,
}

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function ObjectiveController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local park = Workspace:WaitForChild("ParkParkWorld")
	local entrance = park:WaitForChild("RuinedEntrance")
	local carousel = park:WaitForChild("BrokenCarousel")
	local teacups = park:WaitForChild("TeacupsRide")
	local debrisTarget = entrance:WaitForChild("EntranceDebris"):WaitForChild("CleanupTarget")
	local console = carousel:WaitForChild("RepairConsole")
	local teacupsConsole = teacups:WaitForChild("TeacupsConsole")
	local gateAnchor = park:WaitForChild("GateAnchor")
	local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins") :: IntValue
	local currency = GameConfig.CurrencyDisplayName

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ParkParkObjective"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 9
	screenGui.Parent = playerGui

	local card = Instance.new("Frame")
	card.Name = "ObjectiveCard"
	card.Position = UDim2.fromOffset(16, 92)
	card.Size = UDim2.fromOffset(250, 60)
	card.BackgroundColor3 = GameConfig.Palette.Cream
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.Parent = screenGui
	addCorner(card, 16)

	local outline = Instance.new("UIStroke")
	outline.Color = GameConfig.Palette.Mint
	outline.Thickness = 1.5
	outline.Parent = card

	local stepLabel = Instance.new("TextLabel")
	stepLabel.Name = "Step"
	stepLabel.Position = UDim2.fromOffset(14, 8)
	stepLabel.Size = UDim2.new(1, -24, 0, 20)
	stepLabel.BackgroundTransparency = 1
	stepLabel.Font = Enum.Font.GothamBold
	stepLabel.TextColor3 = GameConfig.Palette.Ink
	stepLabel.TextSize = 15
	stepLabel.TextXAlignment = Enum.TextXAlignment.Left
	stepLabel.TextTruncate = Enum.TextTruncate.AtEnd
	stepLabel.Parent = card

	local detailLabel = Instance.new("TextLabel")
	detailLabel.Name = "Detail"
	detailLabel.Position = UDim2.fromOffset(14, 31)
	detailLabel.Size = UDim2.new(1, -24, 0, 18)
	detailLabel.BackgroundTransparency = 1
	detailLabel.Font = Enum.Font.GothamMedium
	detailLabel.TextColor3 = GameConfig.Palette.Ink
	detailLabel.TextTransparency = 0.2
	detailLabel.TextSize = 12
	detailLabel.TextXAlignment = Enum.TextXAlignment.Left
	detailLabel.TextTruncate = Enum.TextTruncate.AtEnd
	detailLabel.Parent = card

	local highlight = Instance.new("Highlight")
	highlight.Name = "ObjectiveHighlight"
	highlight.FillTransparency = 1
	highlight.OutlineColor = GameConfig.Palette.Gold
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = screenGui

	local function currentStep(): Step
		if park:GetAttribute("EntranceCleared") ~= true then
			return {
				title = "1. 입구 쓰레기를 치우세요",
				detail = string.format("치우면 +%d %s", GameConfig.EntranceCleanupReward, currency),
				target = debrisTarget,
			}
		end
		if carousel:GetAttribute("IsRepaired") ~= true then
			local cost = GameConfig.CarouselRepairCost
			return {
				title = "2. 회전목마를 수리하세요",
				detail = if coins.Value >= cost
					then string.format("콘솔에서 수리 · %d %s", cost, currency)
					else string.format("%d %s 필요 · 지금 %d", cost, currency, coins.Value),
				target = console,
			}
		end
		if park:GetAttribute("ParkOpen") ~= true then
			return {
				title = "3. 입구에서 개장하세요",
				detail = "손님들이 회전목마를 타러 와요",
				target = gateAnchor,
			}
		end
		if teacups:GetAttribute("IsUnlocked") ~= true then
			local cost = GameConfig.TeacupsUnlockCost
			return {
				title = "5. 찻잔 라이드 해금",
				detail = if coins.Value >= cost
					then string.format("콘솔에서 해금 · %d %s", cost, currency)
					else string.format("%d %s 필요 · 지금 %d", cost, currency, coins.Value),
				target = teacupsConsole,
			}
		end
		if teacups:GetAttribute("IsRepaired") ~= true then
			local cost = GameConfig.TeacupsRepairCost
			return {
				title = "6. 찻잔 라이드 수리",
				detail = if coins.Value >= cost
					then string.format("콘솔에서 수리 · %d %s", cost, currency)
					else string.format("%d %s 필요 · 지금 %d", cost, currency, coins.Value),
				target = teacupsConsole,
			}
		end
		return {
			title = "7. 찻잔 손님을 맞이하세요",
			detail = string.format("탑승 1회마다 +%d %s", GameConfig.TeacupsGuestRideFare, currency),
			target = nil,
		}
	end

	local function refresh()
		local step = currentStep()
		stepLabel.Text = step.title
		detailLabel.Text = step.detail
		-- The gate anchor is invisible, so outline the entrance itself for the opening step.
		local target = if step.target == gateAnchor then entrance else step.target
		highlight.Adornee = target
		highlight.Enabled = target ~= nil
	end

	park:GetAttributeChangedSignal("EntranceCleared"):Connect(refresh)
	park:GetAttributeChangedSignal("ParkOpen"):Connect(refresh)
	carousel:GetAttributeChangedSignal("IsRepaired"):Connect(refresh)
	teacups:GetAttributeChangedSignal("IsUnlocked"):Connect(refresh)
	teacups:GetAttributeChangedSignal("IsRepaired"):Connect(refresh)
	coins:GetPropertyChangedSignal("Value"):Connect(refresh)
	refresh()
end

return ObjectiveController
