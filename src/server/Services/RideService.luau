--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ParkBuilder = require(script.Parent:WaitForChild("ParkBuilder"))
local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Runs every attraction's economy: unlock, repair, then income and staff upgrades. Players do all of it
-- from one "관리" prompt on each console, which opens the client's manage panel; the panel sends
-- `RideAction` (ride key, action) and this service validates and performs it. A fixed sign above each
-- console shows the ride's state at a glance. The state the panel needs is published as attributes on the
-- ride model (IsUnlocked, IsRepaired, IncomeLevel, StaffLevel, Fare, StaffInterval, QueueLength, and
-- BlockedReason, the text that says why unlocking or repairing is not possible yet).
local RideService = {}

type ExtraRide = ParkBuilder.ExtraRide

type RideReferences = {
	Extras: { [string]: ExtraRide },
	ParkFolder: Folder,
	Carousel: Model,
	CarouselRotor: Model,
	RepairConsole: BasePart,
	TeacupsRide: Model,
	TeacupsRotor: Model,
	TeacupCups: Model?,
	TeacupsConsole: BasePart,
	BumperRide: Model,
	BumperConsole: BasePart,
	SnackStand: Model,
	SnackConsole: BasePart,
	FerrisRide: Model,
	FerrisConsole: BasePart,
	SwingRide: Model,
	SwingConsole: BasePart,
	PirateRide: Model,
	PirateConsole: BasePart,
	HauntedHouse: Model,
	HauntedConsole: BasePart,
	CoasterRide: Model,
	CoasterConsole: BasePart,
	FlumeRide: Model,
	FlumeConsole: BasePart,
	DropRide: Model,
	DropConsole: BasePart,
	GiftShop: Model,
	GiftConsole: BasePart,
	TrainRide: Model,
	TrainConsole: BasePart,
}

type SpendCoins = (Player, number) -> boolean
type GetCoins = (Player) -> number
type ApplyRepairedAppearance = (Model) -> ()
type Notify = (Player, string, string) -> ()

-- One attraction: `isAvailable` says when the park is ready for it (the entrance is clean, the park is open),
-- `signals` fire when that may have changed, and `start` sets it running once repaired.
type RideDefinition = {
	key: string,
	model: Model,
	console: BasePart,
	isAvailable: () -> boolean,
	signals: { RBXScriptSignal },
	start: () -> (),
	applyRepairedAppearance: ApplyRepairedAppearance,
}

local ACTION_DISTANCE = 26
local ACTIONS = { Unlock = true, Repair = true, Income = true, Staff = true }
local SIGN_SIZE = Vector3.new(12, 6.4, 0.5)
local SIGN_CANVAS = Vector2.new(1200, 640)

local function isNear(player: Player, target: BasePart): boolean
	if player.Parent ~= Players then
		return false
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or rootPart == nil or not rootPart:IsA("BasePart") then
		return false
	end

	return (rootPart.Position - target.Position).Magnitude <= ACTION_DISTANCE
end

local function signLabel(parent: Instance, y: number, height: number, size: number, bold: boolean, color: Color3)
	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(30, y)
	label.Size = UDim2.new(1, -60, 0, height)
	label.BackgroundTransparency = 1
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	label.TextColor3 = color
	label.TextSize = size
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent
	return label
end

-- A signboard's SurfaceGui is a texture on the board, so its text turns to mush when seen from far away. Beside
-- it every sign carries a screen-space BillboardGui (`FarLabel`): crisp at any distance, switched on by the
-- client's SignLODController when the camera is far and off when it is near (then the SurfaceGui shows).
local function createFarLabel(board: BasePart, height: number, title: string, subtitle: string): (string) -> ()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FarLabel"
	billboard.Size = UDim2.fromOffset(230, 78)
	billboard.StudsOffset = Vector3.new(0, height, 0)
	billboard.MaxDistance = 130
	billboard.LightInfluence = 0
	billboard.Enabled = false
	billboard.Parent = board
	local function line(y: number, h: number, color: Color3, text: string): TextLabel
		local text_ = Instance.new("TextLabel")
		text_.Position = UDim2.fromOffset(0, y)
		text_.Size = UDim2.new(1, 0, 0, h)
		text_.BackgroundTransparency = 1
		text_.Font = Enum.Font.GothamBlack
		text_.Text = text
		text_.TextColor3 = color
		text_.TextStrokeColor3 = Color3.fromRGB(255, 248, 232)
		text_.TextStrokeTransparency = 0
		text_.TextScaled = true
		text_.Parent = billboard
		return text_
	end
	line(0, 42, GameConfig.Palette.Ink, title)
	local sub = line(44, 34, Color3.fromRGB(206, 78, 64), subtitle)
	return function(text: string)
		sub.Text = text
	end
end

-- A signboard on a post above the console, readable from both sides: the ride's name, what each guest pays,
-- its upgrade levels, and its line. It replaces the small floating panel, whose text was hard to read.
-- Returns a function that rewrites the three changing lines.
local function createInfoSign(console: BasePart, ride: Model, displayName: string): (string, string, string) -> ()
	local parent = console.Parent or ride
	local old = parent:FindFirstChild("InfoSign")
	if old then
		old:Destroy()
	end

	local sign = Instance.new("Model")
	sign.Name = "InfoSign"

	local outward =
		Vector3.new(console.Position.X - ride:GetPivot().Position.X, 0, console.Position.Z - ride:GetPivot().Position.Z)
	outward = if outward.Magnitude > 1 then outward.Unit else Vector3.new(0, 0, 1)
	local postHeight = 3
	local top = console.Position + Vector3.new(0, console.Size.Y / 2, 0)
	local boardCenter = top + Vector3.new(0, postHeight + SIGN_SIZE.Y / 2, 0)

	local post = Instance.new("Part")
	post.Name = "SignPost"
	post.Shape = Enum.PartType.Cylinder
	post.Size = Vector3.new(postHeight + 0.5, 0.7, 0.7)
	post.CFrame = CFrame.new(top + Vector3.new(0, postHeight / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	post.Color = GameConfig.Palette.Gold
	post.Material = Enum.Material.SmoothPlastic
	post.Anchored = true
	post.CanCollide = false
	post.CanQuery = false
	post.CanTouch = false
	post.Parent = sign

	local board = Instance.new("Part")
	board.Name = "SignBoard"
	board.Size = SIGN_SIZE
	board.CFrame = CFrame.lookAt(boardCenter, boardCenter + outward)
	board.Color = GameConfig.Palette.Cream
	board.Material = Enum.Material.SmoothPlastic
	board.Anchored = true
	board.CanCollide = false
	board.CanQuery = false
	board.CanTouch = false
	board.Parent = sign

	local frame = Instance.new("Part")
	frame.Name = "SignFrame"
	frame.Size = SIGN_SIZE + Vector3.new(0.6, 0.6, -0.2)
	frame.CFrame = board.CFrame
	frame.Color = GameConfig.Palette.Gold
	frame.Material = Enum.Material.SmoothPlastic
	frame.Anchored = true
	frame.CanCollide = false
	frame.CanQuery = false
	frame.CanTouch = false
	frame.Parent = sign

	local faces: { { fare: TextLabel, detail: TextLabel, queue: TextLabel } } = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = SIGN_CANVAS
		gui.LightInfluence = 0
		gui.Parent = board

		local ink = GameConfig.Palette.Ink
		local title = signLabel(gui, 24, 130, 116, true, ink)
		title.Text = displayName
		table.insert(faces, {
			fare = signLabel(gui, 160, 112, 92, true, Color3.fromRGB(206, 78, 64)),
			detail = signLabel(gui, 290, 90, 64, true, ink),
			queue = signLabel(gui, 385, 90, 64, true, ink),
		})
		local hint = signLabel(gui, 510, 100, 62, true, Color3.fromRGB(52, 128, 100))
		hint.Text = "콘솔에서 E · 관리"
	end
	local setFar = createFarLabel(board, SIGN_SIZE.Y / 2 + 1.5, displayName, "")
	sign.Parent = parent

	return function(fare: string, detail: string, queue: string)
		setFar(fare)
		for _, face in faces do
			face.fare.Text = fare
			face.detail.Text = detail
			face.queue.Text = queue
		end
	end
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
	applyPirateRepaired: ApplyRepairedAppearance,
	applyHauntedRepaired: ApplyRepairedAppearance,
	applyCoasterRepaired: ApplyRepairedAppearance,
	applyFlumeRepaired: ApplyRepairedAppearance,
	applyDropRepaired: ApplyRepairedAppearance,
	applyGiftRepaired: ApplyRepairedAppearance,
	applyTrainRepaired: ApplyRepairedAppearance,
	applyExtraRepaired: ApplyRepairedAppearance,
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
		Pirate = park.PirateRide,
		Haunted = park.HauntedHouse,
		Coaster = park.CoasterRide,
		Flume = park.FlumeRide,
		Drop = park.DropRide,
		Gift = park.GiftShop,
		Train = park.TrainRide,
	}
	for key, extra in park.Extras do
		rideModels[key] = extra.Ride
	end
	local actions: { [string]: { [string]: (Player) -> () } } = {}

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
		local requiresKey = config.Requires
		local requiredModel = if requiresKey then rideModels[requiresKey] else nil
		-- A shop serves its guests; a ride seats them.
		local staffAction = if config.IsShop == true then "서빙해요" else "태워요"
		local started = false

		-- The old per-action prompts are gone: everything is done from the manage panel.
		for _, legacy in { "UnlockPrompt", "RepairPrompt", "IncomePrompt", "StaffPrompt" } do
			local prompt = ride.console:FindFirstChild(legacy)
			if prompt then
				prompt:Destroy()
			end
		end
		local manage = Instance.new("ProximityPrompt")
		manage.Name = "ManagePrompt"
		manage.ActionText = "관리"
		manage.ObjectText = displayName
		manage.HoldDuration = 0
		manage.MaxActivationDistance = 18
		manage.RequiresLineOfSight = false
		manage.KeyboardKeyCode = Enum.KeyCode.E
		manage:SetAttribute("RideKey", ride.key)
		manage.Parent = ride.console

		-- Each attraction opens up only after the one before it in the chain has been repaired.
		local function prerequisiteDone(): boolean
			return requiredModel == nil or requiredModel:GetAttribute("IsRepaired") == true
		end
		local function isReady(): boolean
			return ride.isAvailable() and prerequisiteDone()
		end
		-- Why the ride cannot be unlocked or repaired yet ("" when it can).
		local function blockedReason(): string
			if not prerequisiteDone() then
				return string.format("먼저 %s 수리", GameConfig.Rides[requiresKey :: string].DisplayName)
			end
			if config.Zone and park.ParkFolder:GetAttribute("Zone_" .. config.Zone) ~= true then
				return string.format("먼저 %s을 여세요", GameConfig.ZoneNames[config.Zone])
			end
			if not ride.isAvailable() then
				return if ride.key == "Carousel"
					then "입구 쓰레기를 먼저 치우세요"
					else "공원을 먼저 개장하세요"
			end
			return ""
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

		-- GuestService reads Fare and StaffInterval each time a guest boards; the panel reads them too.
		local function publishRates()
			model:SetAttribute("Fare", fareForLevel(incomeLevel()))
			local level = staffLevel()
			model:SetAttribute("StaffInterval", if level > 0 then GameConfig.StaffIntervals[level] else 0)
		end
		publishRates()

		local setSign = createInfoSign(ride.console, model, displayName)

		local function refreshBoard()
			model:SetAttribute("BlockedReason", blockedReason())
			local fare = fareForLevel(incomeLevel())
			if not unlocked then
				local reason = blockedReason()
				setSign(
					string.format("손님당 +%d %s", config.BaseFare, currency),
					string.format("해금 %d %s", config.UnlockCost, currency),
					if reason == "" then "잠겨 있어요" else reason
				)
			elseif not repaired then
				setSign(
					string.format("손님당 +%d %s", config.BaseFare, currency),
					string.format("수리 %d %s", config.RepairCost, currency),
					"고장 났어요"
				)
			else
				local queueLength = (model:GetAttribute("QueueLength") :: number?) or 0
				local interval = (model:GetAttribute("StaffInterval") :: number?) or 0
				setSign(
					string.format("손님당 +%d %s", fare, currency),
					string.format(
						"요금 Lv %d/%d · 직원 Lv %d/%d",
						incomeLevel(),
						#config.IncomeCosts,
						staffLevel(),
						#config.StaffCosts
					),
					if interval > 0
						then string.format(
							"대기 %d/%d · 직원이 %d초마다 %s",
							queueLength,
							GameConfig.QueueMax,
							interval,
							staffAction
						)
						else string.format(
							"대기 %d/%d · 손님에게 다가가 허용",
							queueLength,
							GameConfig.QueueMax
						)
				)
			end
		end

		for _, signal in ride.signals do
			signal:Connect(refreshBoard)
		end
		if requiredModel then
			requiredModel:GetAttributeChangedSignal("IsRepaired"):Connect(refreshBoard)
		end
		for _, attribute in { "QueueLength", "IncomeLevel", "StaffLevel" } do
			model:GetAttributeChangedSignal(attribute):Connect(function()
				publishRates()
				refreshBoard()
			end)
		end
		refreshBoard()
		if repaired then
			start()
		end

		local function notEnough(player: Player, cost: number, verb: string)
			notify(
				player,
				string.format("%s이 부족해요", currency),
				string.format("%s에 %d %s이 필요해요 (지금 %d)", verb, cost, currency, getCoins(player))
			)
		end

		local function unlock(player: Player)
			if unlocked or config.UnlockCost == 0 or not isReady() or not isNear(player, ride.console) then
				return
			end
			if not spendCoins(player, config.UnlockCost) then
				notEnough(player, config.UnlockCost, "해금")
				return
			end

			unlocked = true
			model:SetAttribute("IsUnlocked", true)
			refreshBoard()
			notify(
				player,
				string.format("%s 해금!", displayName),
				string.format("-%d %s · 이제 수리하세요", config.UnlockCost, currency)
			)
		end

		local function repair(player: Player)
			if not unlocked or repaired or not isReady() or not isNear(player, ride.console) then
				return
			end
			if not spendCoins(player, config.RepairCost) then
				notEnough(player, config.RepairCost, "수리")
				return
			end

			repaired = true
			ride.applyRepairedAppearance(model)
			model:SetAttribute("IsRepaired", true)
			refreshBoard()
			notify(
				player,
				string.format("%s 복구 완료!", displayName),
				string.format("-%d %s · 손님당 +%d %s", config.RepairCost, currency, config.BaseFare, currency)
			)
			start()
		end

		local function income(player: Player)
			local level = incomeLevel()
			local cost = config.IncomeCosts[level + 1]
			if not repaired or cost == nil or not isNear(player, ride.console) then
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
		end

		local function staff(player: Player)
			local level = staffLevel()
			local cost = config.StaffCosts[level + 1]
			if not repaired or cost == nil or not isNear(player, ride.console) then
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
		end

		actions[ride.key] = { Unlock = unlock, Repair = repair, Income = income, Staff = staff }
	end

	local events = ReplicatedStorage:WaitForChild("ParkParkEvents")
	local actionEvent = events:FindFirstChild("RideAction")
	if actionEvent == nil then
		actionEvent = Instance.new("RemoteEvent")
		actionEvent.Name = "RideAction"
		actionEvent.Parent = events
	end
	local lastAction: { [Player]: number } = {}
	local actionRemote = actionEvent :: RemoteEvent
	Players.PlayerRemoving:Connect(function(player: Player)
		lastAction[player] = nil
	end)
	actionRemote.OnServerEvent:Connect(function(player: Player, key: unknown, action: unknown)
		if type(key) ~= "string" or type(action) ~= "string" or not ACTIONS[action] then
			return
		end
		local handlers = actions[key]
		if handlers == nil then
			return
		end
		-- One action at a time per player, so a mashed button cannot buy twice in a frame.
		local now = os.clock()
		if now - (lastAction[player] or 0) < 0.15 then
			return
		end
		lastAction[player] = now
		handlers[action](player)
	end)

	local carouselRotationSeconds = GameConfig.CarouselRotationSeconds
	setupRide({
		key = "Carousel",
		model = park.Carousel,
		console = park.RepairConsole,
		isAvailable = function()
			return park.ParkFolder:GetAttribute("EntranceCleared") == true
		end,
		signals = { park.ParkFolder:GetAttributeChangedSignal("EntranceCleared") },
		start = function()
			startRotation(park.Carousel, park.CarouselRotor, carouselRotationSeconds, "Carousel")
		end,
		applyRepairedAppearance = applyCarouselRepaired,
	})

	local function parkOpen(): boolean
		return park.ParkFolder:GetAttribute("ParkOpen") == true
	end
	local parkOpenSignal = park.ParkFolder:GetAttributeChangedSignal("ParkOpen")

	setupRide({
		key = "Teacups",
		model = park.TeacupsRide,
		console = park.TeacupsConsole,
		isAvailable = parkOpen,
		signals = { parkOpenSignal },
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

	-- The snack stand is a shop: guests buy a snack at the counter instead of taking a seat.
	setupRide({
		key = "Snack",
		model = park.SnackStand,
		console = park.SnackConsole,
		isAvailable = parkOpen,
		signals = { parkOpenSignal },
		start = function()
			park.SnackStand:SetAttribute("IsOperating", true)
		end,
		applyRepairedAppearance = applySnackRepaired,
	})

	-- The rest run through their own services (BumperCarService, FerrisService, SwingService), which move
	-- them while IsOperating is true, so starting one only flips that attribute.
	setupRide({
		key = "Bumper",
		model = park.BumperRide,
		console = park.BumperConsole,
		isAvailable = parkOpen,
		signals = { parkOpenSignal },
		start = function()
			park.BumperRide:SetAttribute("IsOperating", true)
		end,
		applyRepairedAppearance = applyBumperRepaired,
	})

	setupRide({
		key = "Ferris",
		model = park.FerrisRide,
		console = park.FerrisConsole,
		isAvailable = parkOpen,
		signals = { parkOpenSignal },
		start = function()
			park.FerrisRide:SetAttribute("IsOperating", true)
		end,
		applyRepairedAppearance = applyFerrisRepaired,
	})

	setupRide({
		key = "Swing",
		model = park.SwingRide,
		console = park.SwingConsole,
		isAvailable = parkOpen,
		signals = { parkOpenSignal },
		start = function()
			park.SwingRide:SetAttribute("IsOperating", park.ParkFolder:GetAttribute("PowerOut") ~= true)
		end,
		applyRepairedAppearance = applySwingRepaired,
	})

	setupRide({
		key = "Pirate",
		model = park.PirateRide,
		console = park.PirateConsole,
		isAvailable = parkOpen,
		signals = { parkOpenSignal },
		start = function()
			park.PirateRide:SetAttribute("IsOperating", park.ParkFolder:GetAttribute("PowerOut") ~= true)
		end,
		applyRepairedAppearance = applyPirateRepaired,
	})

	-- HauntedService flickers the windows while the house operates and has guests inside.
	setupRide({
		key = "Haunted",
		model = park.HauntedHouse,
		console = park.HauntedConsole,
		isAvailable = parkOpen,
		signals = { parkOpenSignal },
		start = function()
			park.HauntedHouse:SetAttribute("IsOperating", park.ParkFolder:GetAttribute("PowerOut") ~= true)
		end,
		applyRepairedAppearance = applyHauntedRepaired,
	})

	-- CoasterService runs the train while IsOperating is true.
	setupRide({
		key = "Coaster",
		model = park.CoasterRide,
		console = park.CoasterConsole,
		isAvailable = parkOpen,
		signals = { parkOpenSignal },
		start = function()
			park.CoasterRide:SetAttribute("IsOperating", park.ParkFolder:GetAttribute("PowerOut") ~= true)
		end,
		applyRepairedAppearance = applyCoasterRepaired,
	})

	-- The flume lies in the water zone: it needs the park open and that zone's gate opened (ZoneService).
	setupRide({
		key = "Flume",
		model = park.FlumeRide,
		console = park.FlumeConsole,
		isAvailable = function()
			return parkOpen() and park.ParkFolder:GetAttribute("Zone_Water") == true
		end,
		signals = { parkOpenSignal, park.ParkFolder:GetAttributeChangedSignal("Zone_Water") },
		start = function()
			park.FlumeRide:SetAttribute("IsOperating", park.ParkFolder:GetAttribute("PowerOut") ~= true)
		end,
		applyRepairedAppearance = applyFlumeRepaired,
	})

	-- The drop tower is in the same zone; DropService runs the gondola while IsOperating is true.
	setupRide({
		key = "Drop",
		model = park.DropRide,
		console = park.DropConsole,
		isAvailable = function()
			return parkOpen() and park.ParkFolder:GetAttribute("Zone_Water") == true
		end,
		signals = { parkOpenSignal, park.ParkFolder:GetAttributeChangedSignal("Zone_Water") },
		start = function()
			park.DropRide:SetAttribute("IsOperating", park.ParkFolder:GetAttribute("PowerOut") ~= true)
		end,
		applyRepairedAppearance = applyDropRepaired,
	})

	-- The gift shop is a shop in the water zone: guests buy a souvenir at the counter.
	setupRide({
		key = "Gift",
		model = park.GiftShop,
		console = park.GiftConsole,
		isAvailable = function()
			return parkOpen() and park.ParkFolder:GetAttribute("Zone_Water") == true
		end,
		signals = { parkOpenSignal, park.ParkFolder:GetAttributeChangedSignal("Zone_Water") },
		start = function()
			park.GiftShop:SetAttribute("IsOperating", park.ParkFolder:GetAttribute("PowerOut") ~= true)
		end,
		applyRepairedAppearance = applyGiftRepaired,
	})

	-- The mini train runs in the kids' zone; TrackService moves it while IsOperating is true.
	setupRide({
		key = "Train",
		model = park.TrainRide,
		console = park.TrainConsole,
		isAvailable = function()
			return parkOpen() and park.ParkFolder:GetAttribute("Zone_Kids") == true
		end,
		signals = { parkOpenSignal, park.ParkFolder:GetAttributeChangedSignal("Zone_Kids") },
		start = function()
			park.TrainRide:SetAttribute("IsOperating", park.ParkFolder:GetAttribute("PowerOut") ~= true)
		end,
		applyRepairedAppearance = applyTrainRepaired,
	})

	-- Data-driven rides (ExtraRides): ExtraRideService moves them while IsOperating is true.
	for key, extra in park.Extras do
		local zone = GameConfig.Rides[key].Zone
		local zoneSignals: { RBXScriptSignal } = { parkOpenSignal }
		if zone then
			table.insert(zoneSignals, park.ParkFolder:GetAttributeChangedSignal("Zone_" .. zone))
		end
		setupRide({
			key = key,
			model = extra.Ride,
			console = extra.Console,
			isAvailable = function()
				return parkOpen() and (zone == nil or park.ParkFolder:GetAttribute("Zone_" .. zone) == true)
			end,
			signals = zoneSignals,
			start = function()
				extra.Ride:SetAttribute("IsOperating", park.ParkFolder:GetAttribute("PowerOut") ~= true)
			end,
			applyRepairedAppearance = applyExtraRepaired,
		})
	end
end

return RideService
