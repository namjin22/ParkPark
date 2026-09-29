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
	TeacupsRide: Model,
	TeacupsRotor: Model,
	TeacupsConsole: BasePart,
	TeacupsUnlockPrompt: ProximityPrompt,
	TeacupsRepairPrompt: ProximityPrompt,
}

type SpendCoins = (Player, number) -> boolean
type GetCoins = (Player) -> number
type ApplyRepairedAppearance = (Model) -> ()
type ApplyTeacupsRepairedAppearance = (Model) -> ()
type Notify = (Player, string, string) -> ()

local function canUsePrompt(player: Player, target: BasePart, prompt: ProximityPrompt): boolean
	if player.Parent ~= Players then
		return false
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or rootPart == nil or not rootPart:IsA("BasePart") then
		return false
	end

	return (rootPart.Position - target.Position).Magnitude <= prompt.MaxActivationDistance + 2
end

function RideService.Start(
	park: RideReferences,
	spendCoins: SpendCoins,
	getCoins: GetCoins,
	applyRepairedAppearance: ApplyRepairedAppearance,
	applyTeacupsRepairedAppearance: ApplyTeacupsRepairedAppearance,
	notify: Notify
)
	local carouselRepaired = park.Carousel:GetAttribute("IsRepaired") == true
	local carouselRotationStarted = false
	local teacupsRotationStarted = false
	local carouselCost = GameConfig.CarouselRepairCost
	local teacupsUnlockCost = GameConfig.TeacupsUnlockCost
	local teacupsRepairCost = GameConfig.TeacupsRepairCost
	local currency = GameConfig.CurrencyDisplayName

	local function startRotation(ride: Model, rotor: Model, rotationSeconds: number, name: string)
		local rotorRoot = rotor.PrimaryPart
		if rotorRoot == nil then
			warn(string.format("[ParkPark] %s rotor has no PrimaryPart", name))
			return
		end

		ride:SetAttribute("IsOperating", true)
		local baseCFrame = rotorRoot.CFrame
		task.spawn(function()
			local angle = 0
			local quarterTurnDuration = rotationSeconds / 4
			while rotorRoot.Parent ~= nil and ride:GetAttribute("IsRepaired") == true do
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

	local function startCarousel()
		if carouselRotationStarted then
			return
		end
		carouselRotationStarted = true
		startRotation(park.Carousel, park.CarouselRotor, GameConfig.CarouselRotationSeconds, "Carousel")
	end

	local function startTeacups()
		if teacupsRotationStarted then
			return
		end
		teacupsRotationStarted = true
		startRotation(park.TeacupsRide, park.TeacupsRotor, GameConfig.TeacupsRotationSeconds, "Teacups")
	end

	park.RepairPrompt.ActionText = "수리하기"
	park.RepairPrompt.ObjectText = string.format("회전목마 · %d %s", carouselCost, currency)
	if carouselRepaired then
		park.RepairPrompt.ActionText = "수리 완료"
		park.RepairPrompt.Enabled = false
		startCarousel()
	end

	park.RepairPrompt.Triggered:Connect(function(player: Player)
		if
			carouselRepaired
			or park.ParkFolder:GetAttribute("EntranceCleared") ~= true
			or not canUsePrompt(player, park.RepairConsole, park.RepairPrompt)
		then
			return
		end

		if not spendCoins(player, carouselCost) then
			notify(
				player,
				string.format("%s이 부족해요", currency),
				string.format("수리에 %d %s이 필요해요 (지금 %d)", carouselCost, currency, getCoins(player))
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
			string.format("-%d %s · 입구에서 개장하세요", carouselCost, currency)
		)
		startCarousel()
	end)

	local teacupsUnlocked = park.TeacupsRide:GetAttribute("IsUnlocked") == true
	local teacupsRepaired = park.TeacupsRide:GetAttribute("IsRepaired") == true
	if teacupsRepaired then
		teacupsUnlocked = true
		park.TeacupsRide:SetAttribute("IsUnlocked", true)
	end

	park.TeacupsUnlockPrompt.ActionText = "해금하기"
	park.TeacupsUnlockPrompt.ObjectText = string.format("찻잔 라이드 · %d %s", teacupsUnlockCost, currency)
	park.TeacupsRepairPrompt.ActionText = "수리하기"
	park.TeacupsRepairPrompt.ObjectText = string.format("찻잔 라이드 · %d %s", teacupsRepairCost, currency)

	local function refreshTeacupsPrompts()
		local parkOpen = park.ParkFolder:GetAttribute("ParkOpen") == true
		park.TeacupsUnlockPrompt.Enabled = parkOpen and not teacupsUnlocked
		park.TeacupsRepairPrompt.Enabled = parkOpen and teacupsUnlocked and not teacupsRepaired
	end

	park.ParkFolder:GetAttributeChangedSignal("ParkOpen"):Connect(refreshTeacupsPrompts)
	refreshTeacupsPrompts()
	if teacupsRepaired then
		park.TeacupsRepairPrompt.ActionText = "수리 완료"
		startTeacups()
	end

	park.TeacupsUnlockPrompt.Triggered:Connect(function(player: Player)
		if
			teacupsUnlocked
			or park.ParkFolder:GetAttribute("ParkOpen") ~= true
			or not canUsePrompt(player, park.TeacupsConsole, park.TeacupsUnlockPrompt)
		then
			return
		end

		if not spendCoins(player, teacupsUnlockCost) then
			notify(
				player,
				"코인이 부족해요",
				string.format(
					"해금에 %d %s이 필요해요 (지금 %d)",
					teacupsUnlockCost,
					currency,
					getCoins(player)
				)
			)
			return
		end

		teacupsUnlocked = true
		park.TeacupsRide:SetAttribute("IsUnlocked", true)
		refreshTeacupsPrompts()
		notify(
			player,
			"찻잔 라이드 해금!",
			string.format("-%d %s · 콘솔에서 수리하세요", teacupsUnlockCost, currency)
		)
	end)

	park.TeacupsRepairPrompt.Triggered:Connect(function(player: Player)
		if
			not teacupsUnlocked
			or teacupsRepaired
			or park.ParkFolder:GetAttribute("ParkOpen") ~= true
			or not canUsePrompt(player, park.TeacupsConsole, park.TeacupsRepairPrompt)
		then
			return
		end

		if not spendCoins(player, teacupsRepairCost) then
			notify(
				player,
				"코인이 부족해요",
				string.format(
					"수리에 %d %s이 필요해요 (지금 %d)",
					teacupsRepairCost,
					currency,
					getCoins(player)
				)
			)
			return
		end

		teacupsRepaired = true
		applyTeacupsRepairedAppearance(park.TeacupsRide)
		park.TeacupsRide:SetAttribute("IsRepaired", true)
		park.TeacupsRepairPrompt.ActionText = "수리 완료"
		refreshTeacupsPrompts()
		notify(
			player,
			"찻잔 라이드 복구 완료!",
			string.format(
				"-%d %s · 탑승 때마다 +%d %s",
				teacupsRepairCost,
				currency,
				GameConfig.TeacupsGuestRideFare,
				currency
			)
		)
		startTeacups()
	end)
end

return RideService
