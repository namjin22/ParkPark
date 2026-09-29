--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local RideService = {}

type RideReferences = {
	ParkFolder: Folder,
	Carousel: Model,
	CarouselRotor: Model,
	RepairConsole: BasePart,
	RepairPrompt: ProximityPrompt,
}

type SpendCoins = (Player, number) -> boolean
type GetCoins = (Player) -> number
type ApplyRepairedAppearance = (Model) -> ()
type Notify = (Player, string, string) -> ()

function RideService.Start(
	park: RideReferences,
	spendCoins: SpendCoins,
	getCoins: GetCoins,
	applyRepairedAppearance: ApplyRepairedAppearance,
	notify: Notify
)
	local carouselRepaired = park.Carousel:GetAttribute("IsRepaired") == true
	local rotationStarted = false
	local cost = GameConfig.CarouselRepairCost
	local currency = GameConfig.CurrencyDisplayName

	local function startCarousel()
		if rotationStarted then
			return
		end

		local rotorRoot = park.CarouselRotor.PrimaryPart
		if rotorRoot == nil then
			warn("[ParkPark] Carousel rotor has no PrimaryPart")
			return
		end

		rotationStarted = true
		park.Carousel:SetAttribute("IsOperating", true)
		local baseCFrame = rotorRoot.CFrame
		task.spawn(function()
			local angle = 0
			local quarterTurnDuration = GameConfig.CarouselRotationSeconds / 4
			while rotorRoot.Parent ~= nil and park.Carousel:GetAttribute("IsRepaired") == true do
				angle = (angle + math.pi / 2) % (math.pi * 2)
				local tween = TweenService:Create(
					rotorRoot,
					TweenInfo.new(quarterTurnDuration, Enum.EasingStyle.Linear),
					{ CFrame = baseCFrame * CFrame.Angles(0, angle, 0) }
				)
				tween:Play()
				if tween.Completed:Wait() ~= Enum.PlaybackState.Completed then
					return
				end
			end
		end)
	end

	park.RepairPrompt.ActionText = "수리하기"
	park.RepairPrompt.ObjectText = string.format("회전목마 · %d %s", cost, currency)
	if carouselRepaired then
		park.RepairPrompt.ActionText = "수리 완료"
		park.RepairPrompt.Enabled = false
		startCarousel()
	end

	park.RepairPrompt.Triggered:Connect(function(player: Player)
		if carouselRepaired or player.Parent ~= Players then
			return
		end
		if park.ParkFolder:GetAttribute("EntranceCleared") ~= true then
			return
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid == nil or humanoid.Health <= 0 or rootPart == nil or not rootPart:IsA("BasePart") then
			return
		end
		if
			(rootPart.Position - park.RepairConsole.Position).Magnitude
			> park.RepairPrompt.MaxActivationDistance + 2
		then
			return
		end

		if not spendCoins(player, cost) then
			notify(
				player,
				string.format("%s이 부족해요", currency),
				string.format("수리에 %d %s이 필요해요 (지금 %d)", cost, currency, getCoins(player))
			)
			return
		end

		carouselRepaired = true
		applyRepairedAppearance(park.Carousel)
		park.Carousel:SetAttribute("IsRepaired", true)
		park.RepairPrompt.ActionText = "수리 완료"
		park.RepairPrompt.Enabled = false
		notify(
			player,
			"회전목마 복구 완료!",
			string.format("-%d %s · 입구에서 개장하세요", cost, currency)
		)
		startCarousel()
	end)
end

return RideService
