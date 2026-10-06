--!strict

local Income = require(
	game:GetService("ReplicatedStorage"):WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("Income")
)
local UITheme = require(
	game:GetService("ReplicatedStorage"):WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("UITheme")
)
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
	corner.CornerRadius = UDim.new(0, math.clamp(math.floor(radius / 2), 4, 10))
	corner.Parent = parent
end

function ObjectiveController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local park = Workspace:WaitForChild("ParkParkWorld")
	local entrance = park:WaitForChild("RuinedEntrance")
	local carousel = park:WaitForChild("BrokenCarousel")
	-- The debris arrives with the entrance, a moment after the park folder; a timeout avoids the yield warning.
	local debris = entrance:WaitForChild("EntranceDebris", 30)
	local debrisTarget = if debris then debris:WaitForChild("CleanupTarget", 30) else nil
	local console = carousel:WaitForChild("RepairConsole")
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
	card.BackgroundColor3 = UITheme.Panel
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.Parent = screenGui
	addCorner(card, 16)

	local outline = Instance.new("UIStroke")
	outline.Color = UITheme.Border
	outline.Thickness = 1
	outline.Parent = card

	local stepLabel = Instance.new("TextLabel")
	stepLabel.Name = "Step"
	stepLabel.Position = UDim2.fromOffset(14, 8)
	stepLabel.Size = UDim2.new(1, -24, 0, 20)
	stepLabel.BackgroundTransparency = 1
	stepLabel.Font = Enum.Font.GothamBold
	stepLabel.TextColor3 = UITheme.Text
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
	detailLabel.TextColor3 = UITheme.Text
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

	local function need(cost: number, ready: string): string
		if coins.Value >= cost then
			return ready
		end
		return string.format(
			"%d %s 필요 · 지금 %d · 쓰레기를 줍거나 놀이기구 수입으로 모으세요",
			cost,
			currency,
			coins.Value
		)
	end

	local function perMinute(key: string): number
		return math.floor(Income.PerMinute(key, 0, 0) + 0.5)
	end

	-- The next attraction in the unlock chain that is not yet repaired, with its console.
	local function nextRide(): (string?, Model?, BasePart?)
		for _, key in GameConfig.RideChain do
			local config = GameConfig.Rides[key]
			local model = park:FindFirstChild(config.ModelName)
			if model and model:IsA("Model") and model:GetAttribute("IsRepaired") ~= true then
				local consolePart = model:FindFirstChild(config.ConsoleName, true)
					or model:FindFirstChild("Console", true)
				return key, model, if consolePart and consolePart:IsA("BasePart") then consolePart else nil
			end
		end
		return nil, nil, nil
	end

	local function currentStep(): Step
		local carouselConfig = GameConfig.Rides.Carousel
		if park:GetAttribute("EntranceCleared") ~= true then
			return {
				title = "1. 입구 쓰레기를 치우세요",
				detail = string.format("치우면 +%d %s", GameConfig.EntranceCleanupReward, currency),
				target = debrisTarget,
			}
		end
		if carousel:GetAttribute("IsRepaired") ~= true then
			return {
				title = "2. 회전목마를 수리하세요",
				detail = need(
					carouselConfig.RepairCost,
					string.format("콘솔에서 E · 수리 %d %s", carouselConfig.RepairCost, currency)
				),
				target = console,
			}
		end
		if park:GetAttribute("ParkOpen") ~= true then
			return {
				title = "3. 입구에서 개장하세요",
				detail = "개장하면 손님이 오고 놀이기구가 수입을 냅니다",
				target = gateAnchor,
			}
		end
		local key, model, target = nextRide()
		if key and model then
			local config = GameConfig.Rides[key]
			-- A ride in a zone that is still closed: the next job is opening the zone at its gate.
			if config.Zone and park:GetAttribute("Zone_" .. config.Zone) ~= true then
				local zoneName = GameConfig.ZoneNames[config.Zone]
				return {
					title = string.format("5. %s 열기", zoneName),
					detail = need(
						GameConfig.ZoneCosts[config.Zone],
						string.format("게이트에서 E · %d %s", GameConfig.ZoneCosts[config.Zone], currency)
					),
					target = park:FindFirstChild("ZoneGate_" .. config.Zone),
				}
			end
			local unlocked = model:GetAttribute("IsUnlocked") == true
			local cost = if unlocked then config.RepairCost else config.UnlockCost
			return {
				title = string.format("5. %s %s", config.DisplayName, if unlocked then "수리" else "해금"),
				detail = need(
					cost,
					string.format("콘솔에서 E · %d %s · 분당 +%d", cost, currency, perMinute(key))
				),
				target = target,
			}
		end
		return {
			title = "6. 놀이기구를 키우세요",
			detail = "콘솔에서 E · 수입 늘리기와 직원 고용",
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
	for _, key in GameConfig.RideChain do
		task.spawn(function()
			local model = park:WaitForChild(GameConfig.Rides[key].ModelName)
			model:GetAttributeChangedSignal("IsUnlocked"):Connect(refresh)
			model:GetAttributeChangedSignal("IsRepaired"):Connect(refresh)
		end)
	end
	park:GetAttributeChangedSignal("GuestsBoarded"):Connect(refresh)
	for zone in GameConfig.ZoneCosts do
		park:GetAttributeChangedSignal("Zone_" .. zone):Connect(refresh)
	end
	coins:GetPropertyChangedSignal("Value"):Connect(refresh)
	refresh()
end

return ObjectiveController
