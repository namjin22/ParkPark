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
	CarouselIncomePrompt: ProximityPrompt,
	CarouselStaffPrompt: ProximityPrompt,
	TeacupsRide: Model,
	TeacupsRotor: Model,
	TeacupCups: Model?,
	TeacupsConsole: BasePart,
	TeacupsUnlockPrompt: ProximityPrompt,
	TeacupsRepairPrompt: ProximityPrompt,
	TeacupsIncomePrompt: ProximityPrompt,
	TeacupsStaffPrompt: ProximityPrompt,
	BumperRide: Model,
	BumperConsole: BasePart,
	BumperUnlockPrompt: ProximityPrompt,
	BumperRepairPrompt: ProximityPrompt,
	BumperIncomePrompt: ProximityPrompt,
	BumperStaffPrompt: ProximityPrompt,
	SnackStand: Model,
	SnackConsole: BasePart,
	SnackUnlockPrompt: ProximityPrompt,
	SnackRepairPrompt: ProximityPrompt,
	SnackIncomePrompt: ProximityPrompt,
	SnackStaffPrompt: ProximityPrompt,
	FerrisRide: Model,
	FerrisConsole: BasePart,
	FerrisUnlockPrompt: ProximityPrompt,
	FerrisRepairPrompt: ProximityPrompt,
	FerrisIncomePrompt: ProximityPrompt,
	FerrisStaffPrompt: ProximityPrompt,
	SwingRide: Model,
	SwingConsole: BasePart,
	SwingUnlockPrompt: ProximityPrompt,
	SwingRepairPrompt: ProximityPrompt,
	SwingIncomePrompt: ProximityPrompt,
	SwingStaffPrompt: ProximityPrompt,
}

type SpendCoins = (Player, number) -> boolean
type GetCoins = (Player) -> number
type ApplyRepairedAppearance = (Model) -> ()
type Notify = (Player, string, string) -> ()

-- One ride's economy: an optional unlock, a repair, then income and staff upgrades that raise what
-- each guest pays and let staff board guests automatically. `isAvailable` says when the console works.
type RideDefinition = {
	key: string,
	model: Model,
	console: BasePart,
	unlockPrompt: ProximityPrompt?,
	repairPrompt: ProximityPrompt,
	incomePrompt: ProximityPrompt,
	staffPrompt: ProximityPrompt,
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

	return (rootPart.Position - target.Position).Magnitude <= prompt.MaxActivationDistance + 4
end

local function createLabel(parent: Instance, name: string, y: number, height: number, size: number, bold: boolean)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = UDim2.fromOffset(12, y)
	label.Size = UDim2.new(1, -24, 0, height)
	label.BackgroundTransparency = 1
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	label.TextColor3 = GameConfig.Palette.Ink
	label.TextSize = size
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent
	return label
end

-- A sign over the console that shows the ride's state, what each guest pays, and its upgrade levels.
local function createInfoBoard(console: BasePart, displayName: string): (TextLabel, TextLabel, TextLabel)
	local existing = console:FindFirstChild("RideInfo")
	if existing then
		existing:Destroy()
	end

	local board = Instance.new("BillboardGui")
	board.Name = "RideInfo"
	board.Size = UDim2.fromOffset(330, 112)
	board.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	board.MaxDistance = 95
	board.LightInfluence = 0
	board.ResetOnSpawn = false
	board.Parent = console

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = GameConfig.Palette.Cream
	card.BackgroundTransparency = 0.06
	card.BorderSizePixel = 0
	card.Parent = board
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = GameConfig.Palette.Gold
	stroke.Thickness = 2
	stroke.Parent = card

	local title = createLabel(card, "Title", 8, 26, 21, true)
	title.Text = displayName
	local fareLine = createLabel(card, "Fare", 38, 24, 17, true)
	local detailLine = createLabel(card, "Detail", 64, 20, 14, false)
	local queueLine = createLabel(card, "Queue", 86, 20, 14, false)
	queueLine.TextTransparency = 0.15
	return fareLine, detailLine, queueLine
end

function RideService.Start(
	park: RideReferences,
	spendCoins: SpendCoins,
	getCoins: GetCoins,
	applyCarouselRepaired: ApplyRepairedAppearance,
	applyTeacupsRepaired: ApplyRepairedAppearance,
	applyBumperRepaired: ApplyRepairedAppearance,
	applySnackRepaired: ApplyRepairedAppearance,
	applyFerrisRepaired: ApplyRepairedAppearance,
	applySwingRepaired: ApplyRepairedAppearance,
	notify: Notify
)
	local currency = GameConfig.CurrencyDisplayName
	local rideModels: { [string]: Model } = {
		Carousel = park.Carousel,
		Teacups = park.TeacupsRide,
		Snack = park.SnackStand,
		Bumper = park.BumperRide,
		Ferris = park.FerrisRide,
		Swing = park.SwingRide,
	}

	local function startRotation(ride: Model, rotor: Model, rotationSeconds: number, name: string)
		local rotorRoot = rotor.PrimaryPart
		if rotorRoot == nil then
			warn(string.format("[ParkPark] %s rotor has no PrimaryPart", name))
			return
		end

		ride:SetAttribute("IsOperating", park.ParkFolder:GetAttribute("PowerOut") ~= true)
		local baseCFrame = rotorRoot.CFrame
		task.spawn(function()
			local angle = 0
			local quarterTurnDuration = rotationSeconds / 4
			while rotorRoot.Parent ~= nil and ride:GetAttribute("IsRepaired") == true do
				-- No power, no turning: wait here until the ride operates again.
				if ride:GetAttribute("IsOperating") ~= true then
					task.wait(0.25)
					continue
				end

				local target = (angle + math.pi / 2) % (math.pi * 2)
				local tween = TweenService:Create(
					rotorRoot,
					TweenInfo.new(quarterTurnDuration, Enum.EasingStyle.Linear),
					{ CFrame = baseCFrame * CFrame.Angles(0, target, 0) }
				)
				local stopper = ride:GetAttributeChangedSignal("IsOperating"):Connect(function()
					if ride:GetAttribute("IsOperating") ~= true then
						tween:Cancel()
					end
				end)
				tween:Play()
				local state = tween.Completed:Wait()
				stopper:Disconnect()
				if state == Enum.PlaybackState.Completed then
					angle = target
				end
			end
		end)
	end

	local function setupRide(ride: RideDefinition)
		local config = GameConfig.Rides[ride.key]
		local model = ride.model
		local displayName = config.DisplayName
		-- A shop serves its guests; a ride seats them.
		local requiresKey = config.Requires
		local requiredModel = if requiresKey then rideModels[requiresKey] else nil
		local boardNoun = if config.IsShop == true then "서빙" else "탑승"
		local staffAction = if config.IsShop == true then "서빙해요" else "태워요"
		local started = false

		-- Each attraction opens up only after the one before it in the chain has been repaired.
		local function prerequisiteDone(): boolean
			return requiredModel == nil or requiredModel:GetAttribute("IsRepaired") == true
		end
		local function isReady(): boolean
			return ride.isAvailable() and prerequisiteDone()
		end

		local function start()
			if started then
				return
			end
			started = true
			ride.start()
		end

		local unlocked = config.UnlockCost == 0 or model:GetAttribute("IsUnlocked") == true
		local repaired = model:GetAttribute("IsRepaired") == true
		if repaired then
			unlocked = true
		end
		model:SetAttribute("IsUnlocked", unlocked)
		if model:GetAttribute("IncomeLevel") == nil then
			model:SetAttribute("IncomeLevel", 0)
		end
		if model:GetAttribute("StaffLevel") == nil then
			model:SetAttribute("StaffLevel", 0)
		end

		local function incomeLevel(): number
			return (model:GetAttribute("IncomeLevel") :: number?) or 0
		end
		local function staffLevel(): number
			return (model:GetAttribute("StaffLevel") :: number?) or 0
		end
		local function fareForLevel(level: number): number
			return config.BaseFare + level * config.IncomePerLevel
		end

		-- GuestService reads these two attributes each time a guest boards.
		local function publishRates()
			model:SetAttribute("Fare", fareForLevel(incomeLevel()))
			local level = staffLevel()
			model:SetAttribute("StaffInterval", if level > 0 then GameConfig.StaffIntervals[level] else 0)
		end
		publishRates()

		local fareLine, detailLine, queueLine = createInfoBoard(ride.console, displayName)

		local function refreshBoard()
			local fare = fareForLevel(incomeLevel())
			if not unlocked then
				fareLine.Text = string.format("손님당 +%d %s", config.BaseFare, currency)
				detailLine.Text = string.format("해금 %d %s", config.UnlockCost, currency)
				queueLine.Text = if prerequisiteDone()
					then "잠겨 있어요"
					else string.format("먼저 %s 수리", GameConfig.Rides[requiresKey :: string].DisplayName)
			elseif not repaired then
				fareLine.Text = string.format("손님당 +%d %s", config.BaseFare, currency)
				detailLine.Text = string.format("수리 %d %s", config.RepairCost, currency)
				queueLine.Text = "고장 났어요"
			else
				fareLine.Text = string.format("손님당 +%d %s", fare, currency)
				detailLine.Text = string.format(
					"요금 Lv %d/%d · 직원 Lv %d/%d",
					incomeLevel(),
					#config.IncomeCosts,
					staffLevel(),
					#config.StaffCosts
				)
				local queueLength = (model:GetAttribute("QueueLength") :: number?) or 0
				local interval = (model:GetAttribute("StaffInterval") :: number?) or 0
				queueLine.Text = if interval > 0
					then string.format(
						"대기 %d/%d · 직원이 %d초마다 %s",
						queueLength,
						GameConfig.QueueMax,
						interval,
						staffAction
					)
					else string.format(
						"대기 %d/%d · 손님에게 다가가 허용하세요",
						queueLength,
						GameConfig.QueueMax
					)
			end
		end

		local function refreshPrompts()
			local available = isReady()
			if ride.unlockPrompt then
				ride.unlockPrompt.ObjectText = string.format(
					"%s · %d %s · 손님당 +%d",
					displayName,
					config.UnlockCost,
					currency,
					config.BaseFare
				)
				ride.unlockPrompt.Enabled = available and not unlocked
			end
			ride.repairPrompt.ObjectText =
				string.format("%s · %d %s · 손님당 +%d", displayName, config.RepairCost, currency, config.BaseFare)
			ride.repairPrompt.Enabled = available and unlocked and not repaired

			local income = incomeLevel()
			local staff = staffLevel()
			local incomeNext = config.IncomeCosts[income + 1]
			local staffNext = config.StaffCosts[staff + 1]
			ride.incomePrompt.Enabled = repaired and incomeNext ~= nil
			if incomeNext then
				ride.incomePrompt.ActionText = string.format("요금 올리기 Lv%d→%d", income, income + 1)
				ride.incomePrompt.ObjectText = string.format(
					"%s · %d %s · 손님당 +%d → +%d",
					displayName,
					incomeNext,
					currency,
					fareForLevel(income),
					fareForLevel(income + 1)
				)
			end
			ride.staffPrompt.Enabled = repaired and staffNext ~= nil
			if staffNext then
				ride.staffPrompt.ActionText = string.format("직원 고용 Lv%d→%d", staff, staff + 1)
				ride.staffPrompt.ObjectText = string.format(
					"%s · %d %s · %d초마다 자동 %s",
					displayName,
					staffNext,
					currency,
					GameConfig.StaffIntervals[staff + 1],
					boardNoun
				)
			end
			refreshBoard()
		end

		for _, signal in ride.signals do
			signal:Connect(refreshPrompts)
		end
		if requiredModel then
			requiredModel:GetAttributeChangedSignal("IsRepaired"):Connect(refreshPrompts)
		end
		for _, attribute in { "QueueLength", "IncomeLevel", "StaffLevel" } do
			model:GetAttributeChangedSignal(attribute):Connect(function()
				publishRates()
				refreshPrompts()
			end)
		end
		refreshPrompts()
		if repaired then
			ride.repairPrompt.ActionText = "수리 완료"
			start()
		end

		local function notEnough(player: Player, cost: number, verb: string)
			notify(
				player,
				string.format("%s이 부족해요", currency),
				string.format("%s에 %d %s이 필요해요 (지금 %d)", verb, cost, currency, getCoins(player))
			)
		end

		if ride.unlockPrompt then
			ride.unlockPrompt.Triggered:Connect(function(player: Player)
				if
					unlocked
					or not isReady()
					or not canUsePrompt(player, ride.console, ride.unlockPrompt :: ProximityPrompt)
				then
					return
				end
				if not spendCoins(player, config.UnlockCost) then
					notEnough(player, config.UnlockCost, "해금")
					return
				end

				unlocked = true
				model:SetAttribute("IsUnlocked", true)
				refreshPrompts()
				notify(
					player,
					string.format("%s 해금!", displayName),
					string.format("-%d %s · 이제 수리하세요", config.UnlockCost, currency)
				)
			end)
		end

		ride.repairPrompt.Triggered:Connect(function(player: Player)
			if
				not unlocked
				or repaired
				or not isReady()
				or not canUsePrompt(player, ride.console, ride.repairPrompt)
			then
				return
			end
			if not spendCoins(player, config.RepairCost) then
				notEnough(player, config.RepairCost, "수리")
				return
			end

			repaired = true
			ride.applyRepairedAppearance(model)
			model:SetAttribute("IsRepaired", true)
			ride.repairPrompt.ActionText = "수리 완료"
			refreshPrompts()
			notify(
				player,
				string.format("%s 복구 완료!", displayName),
				string.format("-%d %s · 손님당 +%d %s", config.RepairCost, currency, config.BaseFare, currency)
			)
			start()
		end)

		ride.incomePrompt.Triggered:Connect(function(player: Player)
			local level = incomeLevel()
			local cost = config.IncomeCosts[level + 1]
			if not repaired or cost == nil or not canUsePrompt(player, ride.console, ride.incomePrompt) then
				return
			end
			if not spendCoins(player, cost) then
				notEnough(player, cost, "요금 인상")
				return
			end

			model:SetAttribute("IncomeLevel", level + 1)
			notify(
				player,
				string.format("%s 요금 인상!", displayName),
				string.format("-%d %s · 손님당 +%d %s", cost, currency, fareForLevel(level + 1), currency)
			)
		end)

		ride.staffPrompt.Triggered:Connect(function(player: Player)
			local level = staffLevel()
			local cost = config.StaffCosts[level + 1]
			if not repaired or cost == nil or not canUsePrompt(player, ride.console, ride.staffPrompt) then
				return
			end
			if not spendCoins(player, cost) then
				notEnough(player, cost, "직원 고용")
				return
			end

			model:SetAttribute("StaffLevel", level + 1)
			notify(
				player,
				string.format("%s 직원 고용!", displayName),
				string.format(
					"-%d %s · %d초마다 자동으로 %s",
					cost,
					currency,
					GameConfig.StaffIntervals[level + 1],
					staffAction
				)
			)
		end)
	end

	local carouselRotationSeconds = GameConfig.CarouselRotationSeconds
	setupRide({
		key = "Carousel",
		model = park.Carousel,
		console = park.RepairConsole,
		unlockPrompt = nil,
		repairPrompt = park.RepairPrompt,
		incomePrompt = park.CarouselIncomePrompt,
		staffPrompt = park.CarouselStaffPrompt,
		isAvailable = function()
			return park.ParkFolder:GetAttribute("EntranceCleared") == true
		end,
		signals = { park.ParkFolder:GetAttributeChangedSignal("EntranceCleared") },
		start = function()
			startRotation(park.Carousel, park.CarouselRotor, carouselRotationSeconds, "Carousel")
		end,
		applyRepairedAppearance = applyCarouselRepaired,
	})

	setupRide({
		key = "Teacups",
		model = park.TeacupsRide,
		console = park.TeacupsConsole,
		unlockPrompt = park.TeacupsUnlockPrompt,
		repairPrompt = park.TeacupsRepairPrompt,
		incomePrompt = park.TeacupsIncomePrompt,
		staffPrompt = park.TeacupsStaffPrompt,
		isAvailable = function()
			return park.ParkFolder:GetAttribute("ParkOpen") == true
		end,
		signals = { park.ParkFolder:GetAttributeChangedSignal("ParkOpen") },
		start = function()
			if park.TeacupCups then
				-- TeacupService turns the hub and spins the cups while IsOperating is true.
				park.TeacupsRide:SetAttribute("IsOperating", true)
			else
				startRotation(park.TeacupsRide, park.TeacupsRotor, GameConfig.TeacupsRotationSeconds, "Teacups")
			end
		end,
		applyRepairedAppearance = applyTeacupsRepaired,
	})

	-- The bumper cars need the snack stand repaired first; BumperCarService moves the cars while
	-- IsOperating is true, so starting this ride only flips that attribute.
	setupRide({
		key = "Bumper",
		model = park.BumperRide,
		console = park.BumperConsole,
		unlockPrompt = park.BumperUnlockPrompt,
		repairPrompt = park.BumperRepairPrompt,
		incomePrompt = park.BumperIncomePrompt,
		staffPrompt = park.BumperStaffPrompt,
		isAvailable = function()
			return park.ParkFolder:GetAttribute("ParkOpen") == true
		end,
		signals = { park.ParkFolder:GetAttributeChangedSignal("ParkOpen") },
		start = function()
			park.BumperRide:SetAttribute("IsOperating", true)
		end,
		applyRepairedAppearance = applyBumperRepaired,
	})

	-- The snack stand is a shop: guests buy a snack at the counter instead of taking a seat.
	setupRide({
		key = "Snack",
		model = park.SnackStand,
		console = park.SnackConsole,
		unlockPrompt = park.SnackUnlockPrompt,
		repairPrompt = park.SnackRepairPrompt,
		incomePrompt = park.SnackIncomePrompt,
		staffPrompt = park.SnackStaffPrompt,
		isAvailable = function()
			return park.ParkFolder:GetAttribute("ParkOpen") == true
		end,
		signals = { park.ParkFolder:GetAttributeChangedSignal("ParkOpen") },
		start = function()
			park.SnackStand:SetAttribute("IsOperating", true)
		end,
		applyRepairedAppearance = applySnackRepaired,
	})

	-- The Ferris wheel needs the bumper cars repaired first; FerrisService turns it while IsOperating is true.
	setupRide({
		key = "Ferris",
		model = park.FerrisRide,
		console = park.FerrisConsole,
		unlockPrompt = park.FerrisUnlockPrompt,
		repairPrompt = park.FerrisRepairPrompt,
		incomePrompt = park.FerrisIncomePrompt,
		staffPrompt = park.FerrisStaffPrompt,
		isAvailable = function()
			return park.ParkFolder:GetAttribute("ParkOpen") == true
		end,
		signals = { park.ParkFolder:GetAttributeChangedSignal("ParkOpen") },
		start = function()
			park.FerrisRide:SetAttribute("IsOperating", true)
		end,
		applyRepairedAppearance = applyFerrisRepaired,
	})

	-- The swing ride follows the Ferris wheel; SwingService turns the crown while IsOperating is true.
	setupRide({
		key = "Swing",
		model = park.SwingRide,
		console = park.SwingConsole,
		unlockPrompt = park.SwingUnlockPrompt,
		repairPrompt = park.SwingRepairPrompt,
		incomePrompt = park.SwingIncomePrompt,
		staffPrompt = park.SwingStaffPrompt,
		isAvailable = function()
			return park.ParkFolder:GetAttribute("ParkOpen") == true
		end,
		signals = { park.ParkFolder:GetAttributeChangedSignal("ParkOpen") },
		start = function()
			park.SwingRide:SetAttribute("IsOperating", park.ParkFolder:GetAttribute("PowerOut") ~= true)
		end,
		applyRepairedAppearance = applySwingRepaired,
	})
end

return RideService
