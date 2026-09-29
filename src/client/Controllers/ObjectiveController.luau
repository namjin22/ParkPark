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
	local bumper = park:WaitForChild("BumperCarsRide")
	local debrisTarget = entrance:WaitForChild("EntranceDebris"):WaitForChild("CleanupTarget")
	local console = carousel:WaitForChild("RepairConsole")
	local teacupsConsole = teacups:WaitForChild("TeacupsConsole")
	local bumperConsole = bumper:WaitForChild("BumperConsole")
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

	local function need(cost: number, ready: string): string
		if coins.Value >= cost then
			return ready
		end
		return string.format(
			"%d %s 필요 · 지금 %d · 쓰레기 줍기와 손님 태우기로 모으세요",
			cost,
			currency,
			coins.Value
		)
	end

	local function fare(key: string): number
		return GameConfig.Rides[key].BaseFare
	end

	local function currentStep(): Step
		local carouselConfig = GameConfig.Rides.Carousel
		local teacupsConfig = GameConfig.Rides.Teacups
		local bumperConfig = GameConfig.Rides.Bumper
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
					string.format(
						"콘솔에서 수리 · %d %s · 손님당 +%d",
						carouselConfig.RepairCost,
						currency,
						fare("Carousel")
					)
				),
				target = console,
			}
		end
		if park:GetAttribute("ParkOpen") ~= true then
			return {
				title = "3. 입구에서 개장하세요",
				detail = "손님들이 놀이기구 앞에 줄을 서요",
				target = gateAnchor,
			}
		end
		if ((park:GetAttribute("GuestsBoarded") :: number?) or 0) < 1 then
			return {
				title = "4. 줄 선 손님을 태워주세요",
				detail = string.format(
					"맨 앞 손님 앞에서 태우기 · 손님당 +%d %s",
					fare("Carousel"),
					currency
				),
				target = nil,
			}
		end
		if teacups:GetAttribute("IsUnlocked") ~= true then
			return {
				title = "5. 찻잔 라이드 해금",
				detail = need(
					teacupsConfig.UnlockCost,
					string.format(
						"콘솔에서 해금 · %d %s · 손님당 +%d",
						teacupsConfig.UnlockCost,
						currency,
						fare("Teacups")
					)
				),
				target = teacupsConsole,
			}
		end
		if teacups:GetAttribute("IsRepaired") ~= true then
			return {
				title = "6. 찻잔 라이드 수리",
				detail = need(
					teacupsConfig.RepairCost,
					string.format("콘솔에서 수리 · %d %s", teacupsConfig.RepairCost, currency)
				),
				target = teacupsConsole,
			}
		end
		if bumper:GetAttribute("IsUnlocked") ~= true then
			return {
				title = "7. 범퍼카 해금",
				detail = need(
					bumperConfig.UnlockCost,
					string.format(
						"콘솔에서 해금 · %d %s · 손님당 +%d",
						bumperConfig.UnlockCost,
						currency,
						fare("Bumper")
					)
				),
				target = bumperConsole,
			}
		end
		if bumper:GetAttribute("IsRepaired") ~= true then
			return {
				title = "8. 범퍼카 수리",
				detail = need(
					bumperConfig.RepairCost,
					string.format("콘솔에서 수리 · %d %s", bumperConfig.RepairCost, currency)
				),
				target = bumperConsole,
			}
		end
		return {
			title = "9. 놀이기구를 키우세요",
			detail = "콘솔에서 요금 올리기(E) · 직원 고용(F)",
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
	park:GetAttributeChangedSignal("GuestsBoarded"):Connect(refresh)
	bumper:GetAttributeChangedSignal("IsUnlocked"):Connect(refresh)
	bumper:GetAttributeChangedSignal("IsRepaired"):Connect(refresh)
	coins:GetPropertyChangedSignal("Value"):Connect(refresh)
	refresh()
end

return ObjectiveController
