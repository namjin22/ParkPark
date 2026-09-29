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
	BumperRide: Model,
	BumperConsole: BasePart,
	BumperUnlockPrompt: ProximityPrompt,
	BumperRepairPrompt: ProximityPrompt,
}

type SpendCoins = (Player, number) -> boolean
type GetCoins = (Player) -> number
type ApplyRepairedAppearance = (Model) -> ()
type Notify = (Player, string, string) -> ()

-- A ride that starts locked: the player pays to unlock it, then pays again to repair it, and it
-- then earns fares from guests. `isAvailable` says when its console prompts may show.
type UnlockableRide = {
	displayName: string,
	model: Model,
	console: BasePart,
	unlockPrompt: ProximityPrompt,
	repairPrompt: ProximityPrompt,
	unlockCost: number,
	repairCost: number,
	fare: number,
	isAvailable: () -> boolean,
	signals: { RBXScriptSignal },
	start: () -> (),
	applyRepairedAppearance: ApplyRepairedAppearance,
}

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
	applyTeacupsRepairedAppearance: ApplyRepairedAppearance,
	applyBumperRepairedAppearance: ApplyRepairedAppearance,
	notify: Notify
)
	local carouselRepaired = park.Carousel:GetAttribute("IsRepaired") == true
	local carouselRotationStarted = false
	local carouselCost = GameConfig.CarouselRepairCost
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

	local function setupUnlockableRide(ride: UnlockableRide)
		local unlocked = ride.model:GetAttribute("IsUnlocked") == true
		local repaired = ride.model:GetAttribute("IsRepaired") == true
		if repaired then
			unlocked = true
			ride.model:SetAttribute("IsUnlocked", true)
		end

		ride.unlockPrompt.ActionText = "해금하기"
		ride.unlockPrompt.ObjectText = string.format("%s · %d %s", ride.displayName, ride.unlockCost, currency)
		ride.repairPrompt.ActionText = "수리하기"
		ride.repairPrompt.ObjectText = string.format("%s · %d %s", ride.displayName, ride.repairCost, currency)

		local function refreshPrompts()
			local available = ride.isAvailable()
			ride.unlockPrompt.Enabled = available and not unlocked
			ride.repairPrompt.Enabled = available and unlocked and not repaired
		end

		for _, signal in ride.signals do
			signal:Connect(refreshPrompts)
		end
		refreshPrompts()
		if repaired then
			ride.repairPrompt.ActionText = "수리 완료"
			ride.start()
		end

		ride.unlockPrompt.Triggered:Connect(function(player: Player)
			if unlocked or not ride.isAvailable() or not canUsePrompt(player, ride.console, ride.unlockPrompt) then
				return
			end

			if not spendCoins(player, ride.unlockCost) then
				notify(
					player,
					string.format("%s이 부족해요", currency),
					string.format(
						"해금에 %d %s이 필요해요 (지금 %d)",
						ride.unlockCost,
						currency,
						getCoins(player)
					)
				)
				return
			end

			unlocked = true
			ride.model:SetAttribute("IsUnlocked", true)
			refreshPrompts()
			notify(
				player,
				string.format("%s 해금!", ride.displayName),
				string.format("-%d %s · 콘솔에서 수리하세요", ride.unlockCost, currency)
			)
		end)

		ride.repairPrompt.Triggered:Connect(function(player: Player)
			if
				not unlocked
				or repaired
				or not ride.isAvailable()
				or not canUsePrompt(player, ride.console, ride.repairPrompt)
			then
				return
			end

			if not spendCoins(player, ride.repairCost) then
				notify(
					player,
					string.format("%s이 부족해요", currency),
					string.format(
						"수리에 %d %s이 필요해요 (지금 %d)",
						ride.repairCost,
						currency,
						getCoins(player)
					)
				)
				return
			end

			repaired = true
			ride.applyRepairedAppearance(ride.model)
			ride.model:SetAttribute("IsRepaired", true)
			ride.repairPrompt.ActionText = "수리 완료"
			refreshPrompts()
			notify(
				player,
				string.format("%s 복구 완료!", ride.displayName),
				string.format("-%d %s · 탑승 때마다 +%d %s", ride.repairCost, currency, ride.fare, currency)
			)
			ride.start()
		end)
	end

	local teacupsRotationStarted = false
	setupUnlockableRide({
		displayName = "찻잔 라이드",
		model = park.TeacupsRide,
		console = park.TeacupsConsole,
		unlockPrompt = park.TeacupsUnlockPrompt,
		repairPrompt = park.TeacupsRepairPrompt,
		unlockCost = GameConfig.TeacupsUnlockCost,
		repairCost = GameConfig.TeacupsRepairCost,
		fare = GameConfig.TeacupsGuestRideFare,
		isAvailable = function()
			return park.ParkFolder:GetAttribute("ParkOpen") == true
		end,
		signals = { park.ParkFolder:GetAttributeChangedSignal("ParkOpen") },
		start = function()
			if teacupsRotationStarted then
				return
			end
			teacupsRotationStarted = true
			startRotation(park.TeacupsRide, park.TeacupsRotor, GameConfig.TeacupsRotationSeconds, "Teacups")
		end,
		applyRepairedAppearance = applyTeacupsRepairedAppearance,
	})

	-- The bumper cars unlock only after the teacups run; BumperCarService moves the cars while
	-- IsOperating is true, so starting this ride only flips that attribute.
	setupUnlockableRide({
		displayName = "범퍼카",
		model = park.BumperRide,
		console = park.BumperConsole,
		unlockPrompt = park.BumperUnlockPrompt,
		repairPrompt = park.BumperRepairPrompt,
		unlockCost = GameConfig.BumperUnlockCost,
		repairCost = GameConfig.BumperRepairCost,
		fare = GameConfig.BumperGuestRideFare,
		isAvailable = function()
			return park.ParkFolder:GetAttribute("ParkOpen") == true
				and park.TeacupsRide:GetAttribute("IsRepaired") == true
		end,
		signals = {
			park.ParkFolder:GetAttributeChangedSignal("ParkOpen"),
			park.TeacupsRide:GetAttributeChangedSignal("IsRepaired"),
		},
		start = function()
			park.BumperRide:SetAttribute("IsOperating", true)
		end,
		applyRepairedAppearance = applyBumperRepairedAppearance,
	})
end

return RideService
