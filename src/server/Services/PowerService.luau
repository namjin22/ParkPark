--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Now and then the park loses power. Every attraction stops (`IsOperating` goes false, so the services that
-- move the rides and let guests board simply wait), the client dims the lights, and a generator beside the
-- entrance path starts flashing. A player holds E there to restore power for a bonus; if nobody does, power
-- returns by itself after a while. `PowerOut` on the park folder is the shared state, and setting the
-- `ForceOutage` attribute on it starts an outage at once (used for testing).
local PowerService = {}

type PowerReferences = {
	ParkFolder: Folder,
	Carousel: Model,
	TeacupsRide: Model,
	BumperRide: Model,
	SnackStand: Model,
	FerrisRide: Model,
	SwingRide: Model,
	PirateRide: Model,
	HauntedHouse: Model,
	CoasterRide: Model,
	FlumeRide: Model,
	DropRide: Model,
	GiftShop: Model,
	TrainRide: Model,
}

type AwardCoins = (Player, number) -> boolean
type Notify = (Player, string, string) -> ()
type Popup = (Vector3, string) -> ()

local GENERATOR_POSITION = ParkLayout.GeneratorPosition

local function buildGenerator(parkFolder: Folder): (BasePart, BasePart, ProximityPrompt)
	local existing = parkFolder:FindFirstChild("Generator")
	if existing and existing:IsA("Model") then
		local body = existing:FindFirstChild("GeneratorBody") :: BasePart
		local lamp = existing:FindFirstChild("GeneratorLamp") :: BasePart
		return body, lamp, body:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	end

	local model = Instance.new("Model")
	model.Name = "Generator"

	local function part(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material)
		local piece = Instance.new("Part")
		piece.Name = name
		piece.Size = size
		piece.Position = position
		piece.Color = color
		piece.Material = material
		piece.Anchored = true
		piece.TopSurface = Enum.SurfaceType.Smooth
		piece.BottomSurface = Enum.SurfaceType.Smooth
		piece.Parent = model
		return piece
	end

	-- A simple box generator with a lamp on top and a crank handle: a placeholder prop, not final art.
	local body = part(
		"GeneratorBody",
		Vector3.new(6, 6, 4),
		GENERATOR_POSITION + Vector3.new(0, 3, 0),
		GameConfig.Palette.Coral,
		Enum.Material.SmoothPlastic
	)
	part(
		"GeneratorBase",
		Vector3.new(7, 0.6, 5),
		GENERATOR_POSITION + Vector3.new(0, 0.3, 0),
		GameConfig.Palette.Ink,
		Enum.Material.Slate
	)
	part(
		"GeneratorStripe",
		Vector3.new(6.2, 1, 4.2),
		GENERATOR_POSITION + Vector3.new(0, 3.5, 0),
		GameConfig.Palette.Cream,
		Enum.Material.SmoothPlastic
	)
	local lamp = part(
		"GeneratorLamp",
		Vector3.new(2, 2, 2),
		GENERATOR_POSITION + Vector3.new(0, 7, 0),
		GameConfig.Palette.Mint,
		Enum.Material.Neon
	)
	lamp.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Name = "GeneratorLight"
	light.Range = 26
	light.Brightness = 1
	light.Color = GameConfig.Palette.Mint
	light.Parent = lamp

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RestorePrompt"
	prompt.ActionText = "전원 켜기"
	prompt.ObjectText = "발전기"
	prompt.HoldDuration = 1.5
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Enabled = false
	prompt.Parent = body

	model.PrimaryPart = body
	model.Parent = parkFolder
	return body, lamp, prompt
end

function PowerService.Start(park: PowerReferences, awardCoins: AwardCoins, notify: Notify, popup: Popup)
	local rides = {
		park.Carousel,
		park.TeacupsRide,
		park.BumperRide,
		park.SnackStand,
		park.FerrisRide,
		park.SwingRide,
		park.PirateRide,
		park.HauntedHouse,
		park.CoasterRide,
		park.FlumeRide,
		park.DropRide,
		park.GiftShop,
		park.TrainRide,
	}
	local _, lamp, prompt = buildGenerator(park.ParkFolder)
	local lampLight = lamp:FindFirstChildOfClass("PointLight")
	local currency = GameConfig.CurrencyDisplayName
	local outageToken = 0

	park.ParkFolder:SetAttribute("PowerOut", false)

	local function setPower(on: boolean)
		park.ParkFolder:SetAttribute("PowerOut", not on)
		for _, ride in rides do
			ride:SetAttribute("IsOperating", on and ride:GetAttribute("IsRepaired") == true)
		end
		prompt.Enabled = not on
		lamp.Color = if on then GameConfig.Palette.Mint else GameConfig.Palette.Coral
		if lampLight then
			lampLight.Color = lamp.Color
		end
	end

	-- A ride repaired during an outage must not start turning until power is back.
	for _, ride in rides do
		ride:GetAttributeChangedSignal("IsOperating"):Connect(function()
			if park.ParkFolder:GetAttribute("PowerOut") == true and ride:GetAttribute("IsOperating") == true then
				ride:SetAttribute("IsOperating", false)
			end
		end)
	end

	local function restore(byPlayer: Player?)
		if park.ParkFolder:GetAttribute("PowerOut") ~= true then
			return
		end
		outageToken += 1
		setPower(true)
		for _, player in Players:GetPlayers() do
			if player == byPlayer then
				awardCoins(player, GameConfig.PowerRestoreReward)
				notify(
					player,
					"전원이 돌아왔어요!",
					string.format(
						"+%d %s · 놀이기구가 다시 움직여요",
						GameConfig.PowerRestoreReward,
						currency
					)
				)
			else
				notify(player, "전원이 돌아왔어요!", "놀이기구가 다시 움직여요")
			end
		end
	end

	local function startOutage()
		if park.ParkFolder:GetAttribute("PowerOut") == true then
			return
		end
		outageToken += 1
		local token = outageToken
		setPower(false)
		for _, player in Players:GetPlayers() do
			notify(player, "정전이에요!", "입구 근처 발전기에서 E를 눌러 전원을 켜세요")
		end
		popup(GENERATOR_POSITION + Vector3.new(0, 12, 0), "정전!")

		task.delay(GameConfig.PowerOutageTimeoutSeconds, function()
			-- Nobody restored it in time: power returns on its own, without the bonus.
			if token == outageToken and park.ParkFolder:GetAttribute("PowerOut") == true then
				restore(nil)
			end
		end)
	end

	prompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			return
		end
		if (root.Position - GENERATOR_POSITION).Magnitude > prompt.MaxActivationDistance + 8 then
			return
		end
		restore(player)
	end)

	local function operatingRides(): number
		local count = 0
		for _, ride in rides do
			if ride:GetAttribute("IsRepaired") == true then
				count += 1
			end
		end
		return count
	end

	-- Schedule: after the park is open and enough attractions run, wait a random while, then cut the power.
	task.spawn(function()
		local nextOutage = os.clock() + math.random(GameConfig.PowerOutageMinSeconds, GameConfig.PowerOutageMaxSeconds)
		while park.ParkFolder.Parent ~= nil do
			task.wait(1)
			if park.ParkFolder:GetAttribute("ForceOutage") == true then
				park.ParkFolder:SetAttribute("ForceOutage", false)
				startOutage()
			elseif
				park.ParkFolder:GetAttribute("ParkOpen") ~= true
				or operatingRides() < GameConfig.PowerOutageMinRides
				or park.ParkFolder:GetAttribute("PowerOut") == true
			then
				-- Not yet (or already dark): keep pushing the next outage back.
				nextOutage = math.max(nextOutage, os.clock() + 30)
			elseif os.clock() >= nextOutage then
				startOutage()
				nextOutage = os.clock()
					+ GameConfig.PowerOutageTimeoutSeconds
					+ math.random(GameConfig.PowerOutageMinSeconds, GameConfig.PowerOutageMaxSeconds)
			end
		end
	end)

	-- The lamp flashes red while the power is out.
	task.spawn(function()
		while park.ParkFolder.Parent ~= nil do
			if park.ParkFolder:GetAttribute("PowerOut") == true then
				lamp.Material = if lamp.Material == Enum.Material.Neon
					then Enum.Material.SmoothPlastic
					else Enum.Material.Neon
			else
				lamp.Material = Enum.Material.Neon
			end
			task.wait(0.5)
		end
	end)
end

return PowerService
