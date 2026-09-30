--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))
local CoasterPath = require(Config:WaitForChild("CoasterPath"))

local PARK_FOLDER_NAME = "ParkParkWorld"
local ENTRANCE_NAME = "RuinedEntrance"
local CAROUSEL_NAME = "BrokenCarousel"
local TEACUPS_NAME = "TeacupsRide"
local BUMPER_NAME = "BumperCarsRide"
local SNACK_NAME = "SnackStand"
local FERRIS_NAME = "FerrisWheelRide"
local SWING_NAME = "SwingRide"
local PIRATE_NAME = "PirateRide"
local HAUNTED_NAME = "HauntedHouse"
local COASTER_NAME = "CoasterRide"
local ASSET_FOLDER_SYNC_TIMEOUT = 5
local ASSET_MANIFEST_SYNC_TIMEOUT = 2
-- Guests spawn on +Z and walk through the entrance toward the rides on -Z (see ParkLayout).
local GUEST_APPROACH_DIRECTION = Vector3.new(0, 0, 1)
-- Authored meshes use -Z as their front, so turn the entrance toward arriving guests.
local GATE_Z = ParkLayout.GateZ
local AUTHORED_ENTRANCE_PIVOT = CFrame.new(0, 0, GATE_Z) * CFrame.Angles(0, math.pi, 0)
local AUTHORED_CAROUSEL_PIVOT = CFrame.new(ParkLayout.Rides.Carousel.Pivot)
local AUTHORED_TEACUPS_PIVOT = CFrame.new(ParkLayout.Rides.Teacups.Pivot)
local AUTHORED_BUMPER_PIVOT = CFrame.new(ParkLayout.Rides.Bumper.Pivot)
-- The graybox stand is built facing +X (toward the path); authored meshes face -Z, so they turn a quarter.
local GRAYBOX_SNACK_PIVOT = CFrame.new(ParkLayout.Rides.Snack.Pivot)
local AUTHORED_SNACK_PIVOT = GRAYBOX_SNACK_PIVOT * CFrame.Angles(0, -math.pi / 2, 0)
-- The wheel is modelled with its axle along local Z; turned a quarter it turns in the YZ plane, facing the path.
local COASTER_PIVOT = CFrame.new(ParkLayout.Rides.Coaster.Pivot)
local HAUNTED_PIVOT = CFrame.new(ParkLayout.Rides.Haunted.Pivot)
local PIRATE_PIVOT = CFrame.new(ParkLayout.Rides.Pirate.Pivot)
local SWING_PIVOT = CFrame.new(ParkLayout.Rides.Swing.Pivot)
local FERRIS_PIVOT = CFrame.new(ParkLayout.Rides.Ferris.Pivot) * CFrame.Angles(0, math.pi / 2, 0)
local DEBRIS_NAME = "EntranceDebris"
-- Beside the path between the spawn and the gate, so the first job is right in front of the player.
local DEBRIS_PIVOT = CFrame.new(-32, 0, 52)
-- The entrance arch is scaled, so the gate rope sits in front of it and spans the gap between the pillars.
local GATE_ROPE_Z = GATE_Z + 8
local GATE_ROPE_HALF_WIDTH = 12.5

type AssetManifest = {
	Models: {
		Entrance: string,
		Carousel: string,
		Debris: string?,
		Teacups: string?,
		Bumper: string?,
		Snack: string?,
		Ferris: string?,
		Swing: string?,
		Pirate: string?,
		Haunted: string?,
		Coaster: string?,
		Litter: string?,
	},
	EntranceSign: string,
	CarouselStates: {
		NeglectedCanopy: string,
		RestoredCanopy: string,
	},
	Palettes: {
		Restored: string,
		Neglected: string,
	}?,
}

local RESTORED_GLOW_NAME = "RestoredGlow"

local assetManifest: AssetManifest = {
	Models = {
		Entrance = ENTRANCE_NAME,
		Carousel = CAROUSEL_NAME,
		Teacups = TEACUPS_NAME,
		Bumper = BUMPER_NAME,
		Snack = SNACK_NAME,
		Ferris = FERRIS_NAME,
		Swing = SWING_NAME,
		Pirate = PIRATE_NAME,
		Haunted = HAUNTED_NAME,
		Coaster = COASTER_NAME,
		Litter = "Litter",
	},
	EntranceSign = "SignPanel",
	CarouselStates = {
		NeglectedCanopy = "CanopyNeglected",
		RestoredCanopy = "CanopyRestored",
	},
}
local loadedManifest: ModuleScript? = nil
local warnedAboutMissingAssets = false

local function getAssetFolder(): Folder?
	local folder = ReplicatedStorage:FindFirstChild("ParkParkAssets")
	if folder == nil then
		folder = ReplicatedStorage:WaitForChild("ParkParkAssets", ASSET_FOLDER_SYNC_TIMEOUT)
	end
	if folder == nil then
		if not warnedAboutMissingAssets then
			warnedAboutMissingAssets = true
			warn("[ParkPark] ParkParkAssets is not synced; building the graybox scene")
		end
		return nil
	end
	if not folder:IsA("Folder") then
		warn("[ParkPark] ReplicatedStorage.ParkParkAssets must be a Folder")
		return nil
	end

	local manifestModule = folder:FindFirstChild("AssetManifest")
	if manifestModule == nil then
		manifestModule = folder:WaitForChild("AssetManifest", ASSET_MANIFEST_SYNC_TIMEOUT)
	end
	if manifestModule and manifestModule:IsA("ModuleScript") and manifestModule ~= loadedManifest then
		loadedManifest = manifestModule
		local ok, result = pcall(require, manifestModule)
		if ok and type(result) == "table" then
			local candidate = result :: any
			if
				type(candidate.Models) == "table"
				and type(candidate.Models.Entrance) == "string"
				and type(candidate.Models.Carousel) == "string"
				and (candidate.Models.Teacups == nil or type(candidate.Models.Teacups) == "string")
				and (candidate.Models.Bumper == nil or type(candidate.Models.Bumper) == "string")
				and (candidate.Models.Snack == nil or type(candidate.Models.Snack) == "string")
				and (candidate.Models.Ferris == nil or type(candidate.Models.Ferris) == "string")
				and (candidate.Models.Swing == nil or type(candidate.Models.Swing) == "string")
				and (candidate.Models.Pirate == nil or type(candidate.Models.Pirate) == "string")
				and (candidate.Models.Haunted == nil or type(candidate.Models.Haunted) == "string")
				and (candidate.Models.Coaster == nil or type(candidate.Models.Coaster) == "string")
				and (candidate.Models.Litter == nil or type(candidate.Models.Litter) == "string")
				and type(candidate.EntranceSign) == "string"
				and type(candidate.CarouselStates) == "table"
				and type(candidate.CarouselStates.NeglectedCanopy) == "string"
				and type(candidate.CarouselStates.RestoredCanopy) == "string"
				and (
					candidate.Palettes == nil
					or (
						type(candidate.Palettes) == "table"
						and type(candidate.Palettes.Restored) == "string"
						and type(candidate.Palettes.Neglected) == "string"
					)
				)
			then
				assetManifest = candidate :: AssetManifest
			else
				warn("[ParkPark] AssetManifest has an invalid model, canopy, or palette entry")
			end
		else
			warn("[ParkPark] Could not load ParkParkAssets.AssetManifest: " .. tostring(result))
		end
	end

	return folder
end

local ParkBuilder = {}

export type References = {
	ParkFolder: Folder,
	Entrance: Model,
	Debris: Model,
	CleanupTarget: BasePart,
	CleanupPrompt: ProximityPrompt,
	Carousel: Model,
	CarouselRotor: Model,
	RepairConsole: BasePart,
	RepairPrompt: ProximityPrompt,
	CarouselIncomePrompt: ProximityPrompt,
	CarouselStaffPrompt: ProximityPrompt,
	TeacupsRide: Model,
	TeacupsRotor: Model,
	-- Nil while the ride still uses the legacy single-mesh rotor (guests then sit on the rotor).
	TeacupCups: Model?,
	TeacupsConsole: BasePart,
	TeacupsUnlockPrompt: ProximityPrompt,
	TeacupsRepairPrompt: ProximityPrompt,
	TeacupsIncomePrompt: ProximityPrompt,
	TeacupsStaffPrompt: ProximityPrompt,
	BumperRide: Model,
	BumperCars: Model,
	BumperConsole: BasePart,
	BumperUnlockPrompt: ProximityPrompt,
	BumperRepairPrompt: ProximityPrompt,
	BumperIncomePrompt: ProximityPrompt,
	BumperStaffPrompt: ProximityPrompt,
	SnackStand: Model,
	SnackCounter: BasePart,
	SnackConsole: BasePart,
	SnackUnlockPrompt: ProximityPrompt,
	SnackRepairPrompt: ProximityPrompt,
	SnackIncomePrompt: ProximityPrompt,
	SnackStaffPrompt: ProximityPrompt,
	FerrisRide: Model,
	FerrisWheel: BasePart,
	FerrisCabins: Model,
	FerrisConsole: BasePart,
	FerrisUnlockPrompt: ProximityPrompt,
	FerrisRepairPrompt: ProximityPrompt,
	FerrisIncomePrompt: ProximityPrompt,
	FerrisStaffPrompt: ProximityPrompt,
	SwingRide: Model,
	SwingCrown: BasePart,
	SwingSeats: Model,
	SwingConsole: BasePart,
	SwingUnlockPrompt: ProximityPrompt,
	SwingRepairPrompt: ProximityPrompt,
	SwingIncomePrompt: ProximityPrompt,
	SwingStaffPrompt: ProximityPrompt,
	PirateRide: Model,
	PirateShip: BasePart,
	PirateConsole: BasePart,
	HauntedHouse: Model,
	HauntedBody: BasePart,
	HauntedConsole: BasePart,
	CoasterRide: Model,
	CoasterCars: Model,
	CoasterConsole: BasePart,
	GateRope: Model,
	GatePrompt: ProximityPrompt,
}

local function createPart(
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	parent: Instance,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.Concrete
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createEntranceSign(panel: BasePart, textColor: Color3)
	if panel:FindFirstChild("EntranceSign") then
		return
	end

	local sign = Instance.new("SurfaceGui")
	sign.Name = "EntranceSign"
	sign.Face = if panel.CFrame.LookVector:Dot(GUEST_APPROACH_DIRECTION) > 0
		then Enum.NormalId.Front
		else Enum.NormalId.Back
	sign.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sign.PixelsPerStud = 60
	sign.Parent = panel

	local label = Instance.new("TextLabel")
	label.Name = "SignText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "PARK PARK"
	label.TextColor3 = textColor
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = sign
end

local function ensureGrayboxApproach(parkFolder: Folder)
	local pathColor = Color3.fromRGB(150, 140, 122)
	if parkFolder:FindFirstChild("EntranceGround") == nil then
		local depth = ParkLayout.GroundMaxZ - ParkLayout.GroundMinZ
		createPart(
			"EntranceGround",
			Vector3.new(ParkLayout.GroundHalfWidth * 2, 1, depth),
			Vector3.new(0, -0.5, (ParkLayout.GroundMaxZ + ParkLayout.GroundMinZ) / 2),
			Color3.fromRGB(104, 122, 82),
			parkFolder,
			Enum.Material.Grass
		)
	end
	if parkFolder:FindFirstChild("CrackedPath") == nil then
		-- The main path runs from the entry point through the gate to the carousel platform's front edge.
		local carousel = ParkLayout.Rides.Carousel
		local frontEdge = carousel.Pivot.Z + carousel.PlatformRadius
		local startZ = ParkLayout.EntryZ + 8
		createPart(
			"CrackedPath",
			Vector3.new(ParkLayout.MainPathHalfWidth * 2, 0.2, startZ - frontEdge),
			Vector3.new(0, 0.1, (startZ + frontEdge) / 2),
			pathColor,
			parkFolder,
			Enum.Material.Cobblestone
		)
	end
	if parkFolder:FindFirstChild("SnackPath") == nil then
		-- A spur off the main path to the snack stand; its queue forms along it.
		local snack = ParkLayout.Rides.Snack
		local innerX = -ParkLayout.MainPathHalfWidth + 1
		local outerX = snack.Pivot.X + 2
		createPart(
			"SnackPath",
			Vector3.new(innerX - outerX, 0.2, ParkLayout.SnackPathHalfWidth * 2),
			Vector3.new((innerX + outerX) / 2, 0.1, ParkLayout.SnackZ),
			pathColor,
			parkFolder,
			Enum.Material.Cobblestone
		)
	end
	if parkFolder:FindFirstChild("FerrisPath") == nil then
		-- A spur off the main path to the Ferris wheel's boarding pad; its queue forms along it.
		local ferris = ParkLayout.Rides.Ferris
		local innerX = ParkLayout.MainPathHalfWidth - 1
		local outerX = ferris.Pivot.X - 2
		createPart(
			"FerrisPath",
			Vector3.new(outerX - innerX, 0.2, ParkLayout.SnackPathHalfWidth * 2),
			Vector3.new((innerX + outerX) / 2, 0.1, ParkLayout.FerrisZ),
			pathColor,
			parkFolder,
			Enum.Material.Cobblestone
		)
	end
	if parkFolder:FindFirstChild("HauntedPath") == nil then
		-- A branch north off the side path to the haunted house's line.
		local haunted = ParkLayout.Rides.Haunted
		local startZ = ParkLayout.SidePathZ + ParkLayout.SidePathHalfWidth - 1
		local endZ = haunted.QueueHead.Z + 8
		createPart(
			"HauntedPath",
			Vector3.new(ParkLayout.SnackPathHalfWidth * 2, 0.2, endZ - startZ),
			Vector3.new(haunted.QueueHead.X, 0.1, (startZ + endZ) / 2),
			pathColor,
			parkFolder,
			Enum.Material.Cobblestone
		)
	end
	if parkFolder:FindFirstChild("CoasterPath") == nil then
		-- A branch north off the side path to the roller coaster's line and station.
		local coaster = ParkLayout.Rides.Coaster
		local startZ = ParkLayout.SidePathZ + ParkLayout.SidePathHalfWidth - 1
		local endZ = coaster.QueueHead.Z + 8
		createPart(
			"CoasterPath",
			Vector3.new(ParkLayout.SnackPathHalfWidth * 2, 0.2, endZ - startZ),
			Vector3.new(coaster.QueueHead.X, 0.1, (startZ + endZ) / 2),
			pathColor,
			parkFolder,
			Enum.Material.Cobblestone
		)
	end
	if parkFolder:FindFirstChild("SidePath") == nil then
		-- One side path crosses the main path and reaches the teacups' and the bumper cars' queues.
		local reach = ParkLayout.SidePathReach
		createPart(
			"SidePath",
			Vector3.new(reach * 2, 0.2, ParkLayout.SidePathHalfWidth * 2),
			Vector3.new(0, 0.1, ParkLayout.SidePathZ),
			pathColor,
			parkFolder,
			Enum.Material.Cobblestone
		)
	end
end

-- A rope across the gate shows the park is still closed; guests are only let in after opening.
-- The rope never blocks the player, who has to reach the debris and the carousel first.
local function ensureGate(parkFolder: Folder): (Model, ProximityPrompt)
	local existing = parkFolder:FindFirstChild("GateRope")
	local rope: Model
	if existing and existing:IsA("Model") then
		rope = existing
	else
		rope = Instance.new("Model")
		rope.Name = "GateRope"
		for _, x in { -GATE_ROPE_HALF_WIDTH, GATE_ROPE_HALF_WIDTH } do
			local post = createPart(
				"RopePost",
				Vector3.new(7, 1.2, 1.2),
				Vector3.new(x, 3.5, GATE_ROPE_Z),
				Color3.fromRGB(235, 171, 69),
				rope,
				Enum.Material.SmoothPlastic
			)
			post.Shape = Enum.PartType.Cylinder
			post.CFrame = CFrame.new(x, 3.5, GATE_ROPE_Z) * CFrame.Angles(0, 0, math.pi / 2)
		end
		local cord = createPart(
			"Rope",
			Vector3.new(GATE_ROPE_HALF_WIDTH * 2, 0.6, 0.6),
			Vector3.new(0, 5.6, GATE_ROPE_Z),
			Color3.fromRGB(232, 92, 82),
			rope,
			Enum.Material.Fabric
		)
		cord.Shape = Enum.PartType.Cylinder
		for _, descendant in rope:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
			end
		end
		rope.Parent = parkFolder
	end

	local anchor = parkFolder:FindFirstChild("GateAnchor")
	if anchor == nil then
		local newAnchor = createPart(
			"GateAnchor",
			Vector3.new(10, 8, 2),
			Vector3.new(0, 4, GATE_ROPE_Z),
			Color3.new(1, 1, 1),
			parkFolder
		)
		newAnchor.Transparency = 1
		newAnchor.CanCollide = false
		newAnchor.CanTouch = false
		newAnchor.CanQuery = false
		anchor = newAnchor
	end
	if not (anchor :: Instance):IsA("BasePart") then
		error("[ParkPark] ParkParkWorld.GateAnchor must be a BasePart")
	end

	local prompt = (anchor :: Instance):FindFirstChild("OpenPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		return rope, prompt
	end
	local openPrompt = Instance.new("ProximityPrompt")
	openPrompt.Name = "OpenPrompt"
	openPrompt.ActionText = "개장하기"
	openPrompt.ObjectText = "파크 파크"
	openPrompt.HoldDuration = 1
	openPrompt.MaxActivationDistance = 24
	openPrompt.RequiresLineOfSight = false
	openPrompt.Enabled = false
	openPrompt.Parent = anchor
	return rope, openPrompt
end

local function hideDefaultBaseplate()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate == nil or not baseplate:IsA("BasePart") then
		return
	end

	-- Keep the default floor as a safety collider, but remove its tiled surface
	-- so it cannot z-fight with the temporary entrance ground.
	baseplate.Transparency = 1
	baseplate.CastShadow = false
	baseplate.CanTouch = false
	baseplate.CanQuery = false
	for _, descendant in baseplate:GetDescendants() do
		if descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = 1
		end
	end
end

local function positionGrayboxSpawn()
	local spawnInstance = Workspace:FindFirstChild("ParkParkSpawn") or Workspace:FindFirstChild("SpawnLocation")
	local spawnLocation: SpawnLocation
	if spawnInstance == nil then
		spawnLocation = Instance.new("SpawnLocation")
	elseif spawnInstance:IsA("SpawnLocation") then
		spawnLocation = spawnInstance
	else
		warn("[ParkPark] Workspace.ParkParkSpawn exists but is not a SpawnLocation")
		return
	end

	spawnLocation.Name = "ParkParkSpawn"
	spawnLocation.Size = Vector3.new(6, 1, 6)
	spawnLocation.CFrame = CFrame.new(0, 0.5, ParkLayout.SpawnZ)
	spawnLocation.Anchored = true
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = true
	spawnLocation.CanTouch = false
	spawnLocation.CanQuery = false
	spawnLocation.Neutral = true
	spawnLocation.Enabled = true
	spawnLocation.Duration = 0
	spawnLocation.AllowTeamChangeOnTouch = false
	for _, descendant in spawnLocation:GetDescendants() do
		if descendant:IsA("Decal") then
			descendant.Transparency = 1
		end
	end
	spawnLocation.Parent = Workspace
end

local function addCleanupPrompt(target: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CleanupPrompt"
	prompt.ActionText = "쓰레기 치우기"
	prompt.ObjectText = "입구 쓰레기"
	prompt.HoldDuration = 1.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = target
end

local function buildGrayboxDebris(entrance: Model): Model
	local debris = Instance.new("Model")
	debris.Name = "EntranceDebris"
	debris.Parent = entrance

	local target = createPart(
		"CleanupTarget",
		Vector3.new(3, 1.5, 3),
		Vector3.new(-12, 0.75, 8),
		Color3.fromRGB(101, 91, 74),
		debris
	)
	createPart(
		"BrokenCrateA",
		Vector3.new(2.2, 1, 1.6),
		Vector3.new(-14.4, 0.5, 9.8),
		Color3.fromRGB(118, 91, 67),
		debris
	)
	createPart(
		"BrokenCrateB",
		Vector3.new(1.5, 0.8, 1.4),
		Vector3.new(-9.8, 0.4, 6.4),
		Color3.fromRGB(112, 106, 89),
		debris
	)

	addCleanupPrompt(target)

	return debris
end

local function buildGrayboxEntrance(parkFolder: Folder): Model
	local entrance = Instance.new("Model")
	entrance.Name = ENTRANCE_NAME
	entrance:SetAttribute("IsGraybox", true)
	entrance.Parent = parkFolder

	createPart("LeftPillar", Vector3.new(4, 14, 4), Vector3.new(-16, 7, 25), Color3.fromRGB(105, 105, 100), entrance)
	createPart("RightPillar", Vector3.new(4, 14, 4), Vector3.new(16, 7, 25), Color3.fromRGB(105, 105, 100), entrance)

	local arch =
		createPart("BrokenArch", Vector3.new(36, 3, 4), Vector3.new(0, 13, 25), Color3.fromRGB(80, 80, 76), entrance)
	createEntranceSign(arch, Color3.fromRGB(255, 241, 210))
	buildGrayboxDebris(entrance)

	return entrance
end

local function prepareCarouselRotor(rotor: Model): Model
	local root = rotor:FindFirstChild("CenterPost")
	if root == nil or not root:IsA("BasePart") then
		error("[ParkPark] CarouselRotor.CenterPost must be a BasePart")
	end

	rotor.PrimaryPart = root
	for _, descendant in rotor:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= root then
			local existingWeld = descendant:FindFirstChild("CarouselRotorWeld")
			local weld: WeldConstraint
			if existingWeld == nil then
				weld = Instance.new("WeldConstraint")
				weld.Name = "CarouselRotorWeld"
				weld.Parent = descendant
			elseif existingWeld:IsA("WeldConstraint") then
				weld = existingWeld
			else
				error("[ParkPark] CarouselRotorWeld must be a WeldConstraint")
			end
			weld.Part0 = root
			weld.Part1 = descendant
			descendant.Anchored = false
		end
	end
	root.Anchored = true
	return rotor
end

local function prepareTeacupsRotor(rotor: Model): Model
	local root = rotor:FindFirstChild("RotorCore")
	if root == nil or not root:IsA("BasePart") then
		error("[ParkPark] TeacupsRotor.RotorCore must be a BasePart")
	end

	rotor.PrimaryPart = root
	for _, descendant in rotor:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= root then
			local existingWeld = descendant:FindFirstChild("TeacupsRotorWeld")
			local weld: WeldConstraint
			if existingWeld == nil then
				local newWeld = Instance.new("WeldConstraint")
				newWeld.Name = "TeacupsRotorWeld"
				newWeld.Parent = descendant
				weld = newWeld
			elseif existingWeld:IsA("WeldConstraint") then
				weld = existingWeld
			else
				error("[ParkPark] TeacupsRotorWeld must be a WeldConstraint")
			end
			weld.Part0 = root
			weld.Part1 = descendant
			descendant.Anchored = false
		end
	end
	root.Anchored = true
	return rotor
end

local function findAuthoredTemplate(name: string): Model?
	local folder = getAssetFolder()
	if folder == nil then
		return nil
	end

	local assetName: string?
	if name == ENTRANCE_NAME then
		assetName = assetManifest.Models.Entrance
	elseif name == CAROUSEL_NAME then
		assetName = assetManifest.Models.Carousel
	elseif name == TEACUPS_NAME then
		assetName = assetManifest.Models.Teacups
	elseif name == BUMPER_NAME then
		assetName = assetManifest.Models.Bumper
	elseif name == SNACK_NAME then
		assetName = assetManifest.Models.Snack
	elseif name == FERRIS_NAME then
		assetName = assetManifest.Models.Ferris
	elseif name == SWING_NAME then
		assetName = assetManifest.Models.Swing
	elseif name == PIRATE_NAME then
		assetName = assetManifest.Models.Pirate
	elseif name == HAUNTED_NAME then
		assetName = assetManifest.Models.Haunted
	elseif name == COASTER_NAME then
		assetName = assetManifest.Models.Coaster
	elseif name == DEBRIS_NAME then
		assetName = assetManifest.Models.Debris
	end

	if assetName == nil then
		return nil
	end

	-- Rojo syncs the folder's children with it, so a missing template was never imported.
	-- Waiting here only delayed every graybox Play start by the timeout per model.
	local template = folder:FindFirstChild(assetName)
	if template == nil then
		return nil
	end
	if not template:IsA("Model") then
		error(string.format("[ParkPark] ParkParkAssets.%s must be a Model", assetName))
	end

	return template
end

local function setVariantVisible(variant: Instance, visible: boolean)
	local function applyVisibility(part: BasePart)
		part.Transparency = if visible then 0 else 1
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = visible
	end

	if variant:IsA("BasePart") then
		applyVisibility(variant)
		return
	end
	for _, descendant in variant:GetDescendants() do
		if descendant:IsA("BasePart") then
			applyVisibility(descendant)
		end
	end
end

-- Authored meshes share one palette UV layout, so a texture swap fades or restores a whole area.
-- Canopy variants carry their own neglected/restored geometry and keep their texture.
local function applyPalette(model: Model, restored: boolean)
	local palettes = assetManifest.Palettes
	if palettes == nil or palettes.Neglected == "" then
		return
	end

	local texture = if restored then palettes.Restored else palettes.Neglected
	for _, descendant in model:GetDescendants() do
		if
			descendant:IsA("MeshPart")
			and (descendant.TextureID == palettes.Restored or descendant.TextureID == palettes.Neglected)
			and descendant.Name ~= assetManifest.CarouselStates.NeglectedCanopy
			and descendant.Name ~= assetManifest.CarouselStates.RestoredCanopy
		then
			descendant.TextureID = texture
		end
	end
end

local function setRestoredGlow(part: Instance?, enabled: boolean, range: number)
	if part == nil or not part:IsA("BasePart") then
		return
	end

	local existing = part:FindFirstChild(RESTORED_GLOW_NAME)
	if existing and existing:IsA("Light") then
		existing.Enabled = enabled
		return
	end

	local light = Instance.new("PointLight")
	light.Name = RESTORED_GLOW_NAME
	light.Color = Color3.fromRGB(255, 205, 140)
	light.Brightness = 2
	light.Range = range
	light.Shadows = false
	light.Enabled = enabled
	light.Parent = part
end

local function applyAuthoredCarouselState(carousel: Model, repaired: boolean)
	local neglectedName = assetManifest.CarouselStates.NeglectedCanopy
	local restoredName = assetManifest.CarouselStates.RestoredCanopy
	local neglected = carousel:FindFirstChild(neglectedName, true)
	local restored = carousel:FindFirstChild(restoredName, true)
	if neglected == nil or restored == nil then
		warn(
			string.format(
				"[ParkPark] Authored %s needs both canopy states (%s and %s)",
				CAROUSEL_NAME,
				neglectedName,
				restoredName
			)
		)
		return
	end

	setVariantVisible(neglected, not repaired)
	setVariantVisible(restored, repaired)
	applyPalette(carousel, repaired)
	setRestoredGlow(restored, repaired, 45)
end

local function applyTeacupsAppearance(ride: Model, repaired: boolean)
	if ride:GetAttribute("IsGraybox") == true then
		for _, descendant in ride:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Material = Enum.Material.SmoothPlastic
				if descendant.Name == "RidePlatform" then
					descendant.Color = if repaired then Color3.fromRGB(91, 186, 154) else Color3.fromRGB(106, 111, 104)
				elseif descendant.Name == "Cup" then
					descendant.Color = if repaired then Color3.fromRGB(235, 122, 108) else Color3.fromRGB(126, 113, 98)
				elseif descendant.Name == "RotorCore" then
					descendant.Color = if repaired then Color3.fromRGB(245, 193, 83) else Color3.fromRGB(119, 107, 91)
				end
			end
		end
	else
		applyPalette(ride, repaired)
	end
	setRestoredGlow(ride:FindFirstChild("RotorCore", true), repaired, 40)
end

local function applyBumperAppearance(ride: Model, repaired: boolean)
	if ride:GetAttribute("IsGraybox") == true then
		for _, descendant in ride:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Material = Enum.Material.SmoothPlastic
				if descendant.Name == "RidePlatform" then
					descendant.Color = if repaired then Color3.fromRGB(91, 186, 154) else Color3.fromRGB(106, 111, 104)
				elseif string.match(descendant.Name, "^BumperCar%d+$") then
					descendant.Color = if repaired then Color3.fromRGB(235, 122, 108) else Color3.fromRGB(126, 113, 98)
				end
			end
		end
	else
		applyPalette(ride, repaired)
	end
	setRestoredGlow(ride:FindFirstChild("RidePlatform"), repaired, 45)
end

local function applySnackAppearance(stand: Model, repaired: boolean)
	if stand:GetAttribute("IsGraybox") == true then
		for _, descendant in stand:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Name ~= "ParkPivot" then
				descendant.Material = Enum.Material.SmoothPlastic
				if descendant.Name == "Awning" then
					descendant.Color = if repaired then Color3.fromRGB(235, 122, 108) else Color3.fromRGB(124, 114, 104)
				elseif descendant.Name == "SnackCounter" or descendant.Name == "BackWall" then
					descendant.Color = if repaired then Color3.fromRGB(255, 232, 190) else Color3.fromRGB(112, 104, 94)
				elseif descendant.Name == "Post" then
					descendant.Color = if repaired then Color3.fromRGB(245, 193, 83) else Color3.fromRGB(96, 88, 78)
				elseif descendant.Name == "SnackSign" then
					descendant.Color = if repaired then Color3.fromRGB(245, 193, 83) else Color3.fromRGB(110, 102, 90)
				end
			end
		end
	else
		applyPalette(stand, repaired)
	end
	setRestoredGlow(stand:FindFirstChild("Awning", true) or stand:FindFirstChild("SnackCounter", true), repaired, 30)
end

local function applyFerrisAppearance(ride: Model, repaired: boolean)
	if ride:GetAttribute("IsGraybox") == true then
		for _, descendant in ride:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Name ~= "ParkPivot" then
				descendant.Material = Enum.Material.SmoothPlastic
				if descendant.Name == "Wheel" then
					descendant.Color = if repaired then Color3.fromRGB(245, 193, 83) else Color3.fromRGB(110, 102, 90)
				elseif string.match(descendant.Name, "^FerrisCabin%d+$") then
					descendant.Color = if repaired then Color3.fromRGB(235, 122, 108) else Color3.fromRGB(126, 113, 98)
				elseif string.match(descendant.Name, "^Leg") or descendant.Name == "BasePad" then
					descendant.Color = if repaired then Color3.fromRGB(255, 232, 190) else Color3.fromRGB(112, 104, 94)
				end
			end
		end
	else
		applyPalette(ride, repaired)
	end
	setRestoredGlow(ride:FindFirstChild("Wheel", true), repaired, 60)
end

local function applySwingAppearance(ride: Model, repaired: boolean)
	if ride:GetAttribute("IsGraybox") == true then
		for _, descendant in ride:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Name ~= "ParkPivot" then
				descendant.Material = Enum.Material.SmoothPlastic
				if descendant.Name == "Crown" then
					descendant.Color = if repaired then Color3.fromRGB(235, 122, 108) else Color3.fromRGB(124, 114, 104)
				elseif string.match(descendant.Name, "^SwingSeat%d+$") then
					descendant.Color = if repaired then Color3.fromRGB(245, 193, 83) else Color3.fromRGB(126, 113, 98)
				elseif descendant.Name == "Tower" or descendant.Name == "RidePlatform" then
					descendant.Color = if repaired then Color3.fromRGB(255, 232, 190) else Color3.fromRGB(112, 104, 94)
				end
			end
		end
	else
		applyPalette(ride, repaired)
	end
	setRestoredGlow(ride:FindFirstChild("Crown", true), repaired, 60)
end

local function applyPirateAppearance(ride: Model, repaired: boolean)
	if ride:GetAttribute("IsGraybox") == true then
		for _, descendant in ride:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Name ~= "ParkPivot" then
				descendant.Material = Enum.Material.SmoothPlastic
				if descendant.Name == "Ship" then
					descendant.Color = if repaired then Color3.fromRGB(235, 122, 108) else Color3.fromRGB(124, 114, 104)
				elseif descendant.Name == "BasePad" or string.match(descendant.Name, "^Leg") then
					descendant.Color = if repaired then Color3.fromRGB(255, 232, 190) else Color3.fromRGB(112, 104, 94)
				end
			end
		end
	else
		applyPalette(ride, repaired)
	end
	setRestoredGlow(ride:FindFirstChild("Ship", true), repaired, 60)
end

local function applyHauntedAppearance(ride: Model, repaired: boolean)
	if ride:GetAttribute("IsGraybox") == true then
		for _, descendant in ride:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Name ~= "ParkPivot" and descendant.Transparency < 1 then
				descendant.Material = Enum.Material.SmoothPlastic
				if descendant.Name == "Roof" or descendant.Name == "TowerCap" then
					descendant.Color = if repaired then Color3.fromRGB(57, 67, 72) else Color3.fromRGB(96, 92, 88)
				elseif descendant.Name == "HouseBody" or descendant.Name == "Tower" then
					descendant.Color = if repaired then Color3.fromRGB(96, 178, 146) else Color3.fromRGB(104, 112, 106)
				end
			end
		end
	else
		applyPalette(ride, repaired)
	end
end

local function applyCoasterAppearance(ride: Model, repaired: boolean)
	if ride:GetAttribute("IsGraybox") == true then
		for _, descendant in ride:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Name ~= "ParkPivot" then
				descendant.Material = Enum.Material.SmoothPlastic
				if descendant.Name == "TrackSegment" or descendant.Name == "Station" then
					descendant.Color = if repaired then Color3.fromRGB(235, 122, 108) else Color3.fromRGB(112, 104, 94)
				elseif string.match(descendant.Name, "^CoasterCar%d+$") then
					descendant.Color = if repaired then Color3.fromRGB(96, 178, 146) else Color3.fromRGB(126, 113, 98)
				end
			end
		end
	else
		applyPalette(ride, repaired)
	end
	setRestoredGlow(ride:FindFirstChild("Station", true) or ride:FindFirstChild("CoasterTrack", true), repaired, 60)
end

local function applyAuthoredEntranceState(entrance: Model, cleared: boolean)
	if entrance:GetAttribute("IsGraybox") == true then
		return
	end
	applyPalette(entrance, cleared)
	setRestoredGlow(entrance:FindFirstChild(assetManifest.EntranceSign, true), cleared, 16)
end

local function ensureGrayboxDebris(entrance: Model): (Model, BasePart, ProximityPrompt)
	local debrisInstance = entrance:FindFirstChild(DEBRIS_NAME)
	local debris: Model
	if debrisInstance == nil then
		local template = findAuthoredTemplate(DEBRIS_NAME)
		if template then
			debris = template:Clone()
			debris.Name = DEBRIS_NAME
			debris:PivotTo(DEBRIS_PIVOT)
			debris.Parent = entrance
			local target = debris:FindFirstChild("CleanupTarget")
			if target and target:IsA("BasePart") and target:FindFirstChild("CleanupPrompt") == nil then
				addCleanupPrompt(target)
			end
		else
			debris = buildGrayboxDebris(entrance)
		end
	elseif debrisInstance:IsA("Model") then
		debris = debrisInstance
	else
		error("[ParkPark] RuinedEntrance.EntranceDebris must be a Model")
	end

	local target = debris:FindFirstChild("CleanupTarget")
	if target == nil or not target:IsA("BasePart") then
		error("[ParkPark] EntranceDebris.CleanupTarget must be a BasePart")
	end
	local prompt = target:FindFirstChild("CleanupPrompt")
	if prompt == nil or not prompt:IsA("ProximityPrompt") then
		error("[ParkPark] EntranceDebris.CleanupTarget.CleanupPrompt must be a ProximityPrompt")
	end

	return debris, target, prompt
end

local function ensureAuthoredEntranceSign(entrance: Model)
	if entrance:FindFirstChild("EntranceSign", true) then
		return
	end

	local panel = entrance:FindFirstChild(assetManifest.EntranceSign, true)
	if panel and panel:IsA("BasePart") then
		-- Dark wood lettering stays readable on both the faded and the bright gold sign.
		createEntranceSign(panel, Color3.fromRGB(74, 42, 28))
	elseif entrance:GetAttribute("IsGraybox") ~= true then
		warn("[ParkPark] Authored RuinedEntrance is missing its SignPanel mesh")
	end
end

local function buildGrayboxCarousel(parkFolder: Folder): Model
	local carousel = Instance.new("Model")
	carousel.Name = CAROUSEL_NAME
	carousel:SetAttribute("IsGraybox", true)
	carousel:SetAttribute("IsRepaired", false)
	carousel.Parent = parkFolder

	createPart("RidePlatform", Vector3.new(22, 1, 22), Vector3.new(0, 0.5, -12), Color3.fromRGB(90, 90, 90), carousel)

	local rotor = Instance.new("Model")
	rotor.Name = "CarouselRotor"
	rotor.Parent = carousel
	createPart("CenterPost", Vector3.new(2, 11, 2), Vector3.new(0, 6, -12), Color3.fromRGB(75, 75, 72), rotor)
	createPart("DamagedCanopy", Vector3.new(18, 1, 18), Vector3.new(0, 11, -12), Color3.fromRGB(80, 80, 76), rotor)
	createPart("CanopySupport", Vector3.new(20, 0.7, 1), Vector3.new(0, 10, -12), Color3.fromRGB(65, 65, 63), rotor)
	createPart("BrokenSeatA", Vector3.new(3, 2, 3), Vector3.new(7, 2, -12), Color3.fromRGB(105, 105, 100), rotor)
	createPart("BrokenSeatB", Vector3.new(3, 2, 3), Vector3.new(-7, 2, -12), Color3.fromRGB(105, 105, 100), rotor)
	createPart("BrokenSeatC", Vector3.new(3, 2, 3), Vector3.new(0, 2, -19), Color3.fromRGB(105, 105, 100), rotor)
	createPart("BrokenSeatD", Vector3.new(3, 2, 3), Vector3.new(0, 2, -5), Color3.fromRGB(105, 105, 100), rotor)
	prepareCarouselRotor(rotor)

	local console = createPart(
		"RepairConsole",
		Vector3.new(2, 3, 2),
		Vector3.new(13, 1.5, -12),
		Color3.fromRGB(70, 70, 68),
		carousel
	)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RepairPrompt"
	prompt.ActionText = "수리하기"
	prompt.ObjectText = "고장 난 회전목마"
	prompt.HoldDuration = 2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = console

	return carousel
end

local function buildGrayboxTeacups(parkFolder: Folder): Model
	local ride = Instance.new("Model")
	ride.Name = TEACUPS_NAME
	ride:SetAttribute("IsGraybox", true)
	ride.Parent = parkFolder

	local pivot = createPart("ParkPivot", Vector3.new(0.1, 0.1, 0.1), Vector3.zero, Color3.new(1, 1, 1), ride)
	pivot.Transparency = 1
	pivot.CanCollide = false
	pivot.CanTouch = false
	pivot.CanQuery = false
	pivot.CastShadow = false
	ride.PrimaryPart = pivot

	local platform = createPart(
		"RidePlatform",
		Vector3.new(0.8, 18.4, 18.4),
		Vector3.new(0, 0.42, 0),
		Color3.fromRGB(105, 112, 98),
		ride,
		Enum.Material.Slate
	)
	platform.Shape = Enum.PartType.Cylinder
	platform.CFrame = CFrame.new(0, 0.42, 0) * CFrame.Angles(0, 0, math.pi / 2)
	platform.CanCollide = false

	local collider =
		createPart("PlatformCollider", Vector3.new(0.7, 18.4, 18.4), Vector3.new(0, 0.42, 0), Color3.new(1, 1, 1), ride)
	collider.Shape = Enum.PartType.Cylinder
	collider.CFrame = CFrame.new(0, 0.42, 0) * CFrame.Angles(0, 0, math.pi / 2)
	collider.Transparency = 1
	collider.CanTouch = false
	collider.CanQuery = false
	collider.CastShadow = false

	local rotor = Instance.new("Model")
	rotor.Name = "TeacupsRotor"
	rotor.Parent = ride
	createPart(
		"RotorCore",
		Vector3.new(1, 8.2, 1),
		Vector3.new(0, 4.72, 0),
		Color3.fromRGB(119, 107, 91),
		rotor,
		Enum.Material.Slate
	)
	local cupColors = {
		Color3.fromRGB(126, 113, 98),
		Color3.fromRGB(116, 120, 103),
		Color3.fromRGB(133, 111, 95),
	}
	for cupIndex = 1, 6 do
		local angle = (cupIndex - 1) * math.pi / 3
		local x, z = 6 * math.cos(angle), 6 * math.sin(angle)
		local cup = createPart(
			"Cup",
			Vector3.new(2.7, 1.4, 2.7),
			Vector3.new(x, 1.9, z),
			cupColors[(cupIndex - 1) % #cupColors + 1],
			rotor,
			Enum.Material.Slate
		)
		cup.Shape = Enum.PartType.Cylinder
		cup.CFrame = CFrame.new(x, 1.9, z) * CFrame.Angles(0, 0, math.pi / 2)
		cup.CanCollide = false
		cup.CanTouch = false
		cup.CanQuery = false

		local armPosition = Vector3.new(x * 0.38, 3.7, z * 0.38)
		local arm = createPart(
			"Arm",
			Vector3.new(0.22, 0.22, 4.7),
			armPosition,
			Color3.fromRGB(158, 132, 91),
			rotor,
			Enum.Material.Metal
		)
		arm.CFrame = CFrame.lookAt(armPosition, Vector3.new(x, 3.7, z))
		arm.CanCollide = false
		arm.CanTouch = false
		arm.CanQuery = false
	end
	prepareTeacupsRotor(rotor)

	local console =
		createPart("TeacupsConsole", Vector3.new(2, 3, 2), Vector3.new(0, 1.5, 10.5), Color3.fromRGB(91, 87, 79), ride)
	console.Material = Enum.Material.Slate
	ride:PivotTo(AUTHORED_TEACUPS_PIVOT)
	return ride
end

local function buildGrayboxBumperCars(parkFolder: Folder): Model
	local ride = Instance.new("Model")
	ride.Name = BUMPER_NAME
	ride:SetAttribute("IsGraybox", true)
	ride.Parent = parkFolder

	local pivot = createPart("ParkPivot", Vector3.new(0.1, 0.1, 0.1), Vector3.zero, Color3.new(1, 1, 1), ride)
	pivot.Transparency = 1
	pivot.CanCollide = false
	pivot.CanTouch = false
	pivot.CanQuery = false
	pivot.CastShadow = false
	ride.PrimaryPart = pivot

	local scale = GameConfig.BumperScale
	local diameter = GameConfig.BumperPlatformRadius * 2 * scale
	local platform = createPart(
		"RidePlatform",
		Vector3.new(0.8, diameter, diameter),
		Vector3.new(0, 0.42, 0),
		Color3.fromRGB(105, 112, 98),
		ride,
		Enum.Material.Slate
	)
	platform.Shape = Enum.PartType.Cylinder
	platform.CFrame = CFrame.new(0, 0.42, 0) * CFrame.Angles(0, 0, math.pi / 2)

	local cars = Instance.new("Model")
	cars.Name = "BumperCars"
	cars.Parent = ride
	local carScale = GameConfig.BumperCarScale
	local carHeight = GameConfig.BumperCarCenterHeight * carScale
	for index = 1, GameConfig.BumperSeatCount do
		local angle = 2 * math.pi * (index - 1) / GameConfig.BumperSeatCount
		local position = Vector3.new(5.5 * scale * math.cos(angle), carHeight, 5.5 * scale * math.sin(angle))
		local car = createPart(
			string.format("BumperCar%d", index),
			Vector3.new(2.5 * carScale, 2.2 * carScale, 3.2 * carScale),
			position,
			Color3.fromRGB(126, 113, 98),
			cars,
			Enum.Material.SmoothPlastic
		)
		car.CanCollide = false
		car.CanTouch = false
		car.CanQuery = false
		car.CFrame = CFrame.lookAt(position, position + Vector3.new(-math.sin(angle), 0, math.cos(angle)))
	end

	local console = createPart(
		"BumperConsole",
		Vector3.new(2, 3, 2),
		Vector3.new(0, 1.5, diameter / 2 + 1.6),
		Color3.fromRGB(91, 87, 79),
		ride
	)
	console.Material = Enum.Material.Slate
	ride:PivotTo(AUTHORED_BUMPER_PIVOT)
	return ride
end

local function buildGrayboxSnackStand(parkFolder: Folder): Model
	local stand = Instance.new("Model")
	stand.Name = SNACK_NAME
	stand:SetAttribute("IsGraybox", true)
	stand.Parent = parkFolder

	local pivot = createPart("ParkPivot", Vector3.new(0.1, 0.1, 0.1), Vector3.zero, Color3.new(1, 1, 1), stand)
	pivot.Transparency = 1
	pivot.CanCollide = false
	pivot.CanTouch = false
	pivot.CanQuery = false
	pivot.CastShadow = false
	stand.PrimaryPart = pivot

	local grey = Color3.fromRGB(112, 104, 94)
	-- The counter faces +X, toward the path; the guests stand in line in front of it.
	createPart("BackWall", Vector3.new(1, 10, 16), Vector3.new(-4, 5, 0), grey, stand, Enum.Material.SmoothPlastic)
	createPart(
		"SnackCounter",
		Vector3.new(4, 3.4, 16),
		Vector3.new(3, 1.7, 0),
		grey,
		stand,
		Enum.Material.SmoothPlastic
	)
	for _, z in { -7.5, 7.5 } do
		createPart("Post", Vector3.new(1.2, 10, 1.2), Vector3.new(5.5, 5, z), grey, stand, Enum.Material.SmoothPlastic)
	end
	local awning = createPart(
		"Awning",
		Vector3.new(12, 0.6, 18),
		Vector3.new(1, 10.3, 0),
		grey,
		stand,
		Enum.Material.SmoothPlastic
	)
	awning.CanCollide = false
	local sign = createPart(
		"SnackSign",
		Vector3.new(0.6, 2.6, 10),
		Vector3.new(6.2, 12, 0),
		grey,
		stand,
		Enum.Material.SmoothPlastic
	)
	sign.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SnackSignText"
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "SNACKS"
	label.TextColor3 = Color3.fromRGB(57, 67, 72)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	local console =
		createPart("SnackConsole", Vector3.new(2, 3, 2), Vector3.new(-7, 1.5, -9.5), Color3.fromRGB(91, 87, 79), stand)
	console.Material = Enum.Material.Slate
	-- Local +X is the front, so the graybox needs no turn.
	stand:PivotTo(GRAYBOX_SNACK_PIVOT)
	return stand
end

-- Graybox Ferris wheel in the authored template's local frame (axle along Z, front -Z).
local function buildGrayboxFerris(parkFolder: Folder): Model
	local ride = Instance.new("Model")
	ride.Name = FERRIS_NAME
	ride:SetAttribute("IsGraybox", true)
	ride.Parent = parkFolder

	local pivot = createPart("ParkPivot", Vector3.new(0.1, 0.1, 0.1), Vector3.zero, Color3.new(1, 1, 1), ride)
	pivot.Transparency = 1
	pivot.CanCollide = false
	pivot.CanTouch = false
	pivot.CanQuery = false
	pivot.CastShadow = false
	ride.PrimaryPart = pivot

	local scale = GameConfig.FerrisScale
	local grey = Color3.fromRGB(112, 104, 94)
	local hub = GameConfig.FerrisHubHeight * scale
	local radius = GameConfig.FerrisRadius * scale
	createPart("BasePad", Vector3.new(11 * scale, 0.6, 8.4 * scale), Vector3.new(0, 0.3, 0), grey, ride)
	for _, z in { -1.4, 1.4 } do
		for _, footX in { -4.4, 4.4 } do
			local foot = Vector3.new(footX * scale, 0.6, z * scale)
			local apex = Vector3.new(0, hub, z * scale)
			local leg = createPart("Leg", Vector3.new(1.4, 1.4, (apex - foot).Magnitude), (foot + apex) / 2, grey, ride)
			leg.CFrame = CFrame.lookAt((foot + apex) / 2, apex)
		end
	end

	-- A thin translucent slab stands in for the wheel. It keeps the model's orientation, because FerrisService
	-- rolls the wheel about its local Z axis (the axle).
	local wheel = createPart(
		"Wheel",
		Vector3.new(radius * 2, radius * 2, 0.6),
		Vector3.new(0, hub, 0),
		grey,
		ride,
		Enum.Material.SmoothPlastic
	)
	wheel.Transparency = 0.45
	wheel.CanCollide = false

	local cabins = Instance.new("Model")
	cabins.Name = "FerrisCabins"
	cabins.Parent = ride
	local count = GameConfig.FerrisCabinCount
	for index = 1, count do
		local angle = 2 * math.pi * (index - 1) / count
		local hanger = Vector3.new(radius * math.cos(angle), hub + radius * math.sin(angle), 0)
		local cabin = createPart(
			string.format("FerrisCabin%d", index),
			Vector3.new(3.1, 3.07, 3.1) * scale,
			hanger + Vector3.new(0, GameConfig.FerrisCabinCenterHeight * scale, 0),
			grey,
			cabins,
			Enum.Material.SmoothPlastic
		)
		cabin.CanCollide = false
		cabin.CanTouch = false
		cabin.CanQuery = false
	end

	-- Behind the wheel, away from the queue that forms toward -X in the world (local -Z).
	local console =
		createPart("FerrisConsole", Vector3.new(2, 3, 2), Vector3.new(8, 1.5, 10), Color3.fromRGB(91, 87, 79), ride)
	console.Material = Enum.Material.Slate
	ride:PivotTo(FERRIS_PIVOT)
	return ride
end

-- Graybox swing ride in the template's local frame: platform, tower, turning crown, and eight hanging seats.
local function buildGrayboxSwing(parkFolder: Folder): Model
	local ride = Instance.new("Model")
	ride.Name = SWING_NAME
	ride:SetAttribute("IsGraybox", true)
	ride.Parent = parkFolder

	local pivot = createPart("ParkPivot", Vector3.new(0.1, 0.1, 0.1), Vector3.zero, Color3.new(1, 1, 1), ride)
	pivot.Transparency = 1
	pivot.CanCollide = false
	pivot.CanTouch = false
	pivot.CanQuery = false
	pivot.CastShadow = false
	ride.PrimaryPart = pivot

	local scale = GameConfig.SwingScale
	local grey = Color3.fromRGB(112, 104, 94)
	local diameter = GameConfig.SwingPlatformRadius * 2 * scale
	local platform = createPart(
		"RidePlatform",
		Vector3.new(0.8, diameter, diameter),
		Vector3.new(0, 0.4, 0),
		grey,
		ride,
		Enum.Material.SmoothPlastic
	)
	platform.Shape = Enum.PartType.Cylinder
	platform.CFrame = CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.pi / 2)

	local towerHeight = GameConfig.SwingTowerHeight * scale
	local tower = createPart(
		"Tower",
		Vector3.new(towerHeight, 2.4 * scale, 2.4 * scale),
		Vector3.new(0, towerHeight / 2, 0),
		grey,
		ride,
		Enum.Material.SmoothPlastic
	)
	tower.Shape = Enum.PartType.Cylinder
	tower.CFrame = CFrame.new(0, towerHeight / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)

	-- A block stands in for the crown so it can turn about the tower's axis (a rolled cylinder could not).
	local crown = createPart(
		"Crown",
		Vector3.new(11 * scale, 0.8 * scale, 11 * scale),
		Vector3.new(0, towerHeight, 0),
		grey,
		ride,
		Enum.Material.SmoothPlastic
	)
	crown.CanCollide = false

	local seats = Instance.new("Model")
	seats.Name = "SwingSeats"
	seats.Parent = ride
	local count = GameConfig.SwingSeatCount
	local center = Vector3.new(GameConfig.SwingSeatCenterX, GameConfig.SwingSeatCenterY, GameConfig.SwingSeatCenterZ)
	for index = 1, count do
		local angle = 2 * math.pi * (index - 1) / count
		local anchor = Vector3.new(
			GameConfig.SwingAnchorRadius * math.cos(angle),
			GameConfig.SwingTowerHeight + GameConfig.SwingAnchorY,
			GameConfig.SwingAnchorRadius * math.sin(angle)
		) * scale
		local seat = createPart(
			string.format("SwingSeat%d", index),
			Vector3.new(1.7, 5.96, 1.27) * scale,
			anchor + center * scale,
			grey,
			seats,
			Enum.Material.SmoothPlastic
		)
		seat.CanCollide = false
		seat.CanTouch = false
		seat.CanQuery = false
	end

	-- Off to the side of the platform, away from the queue that forms along the path to the east.
	local console = createPart(
		"SwingConsole",
		Vector3.new(2, 3, 2),
		Vector3.new(0, 1.5, diameter / 2 + 8),
		Color3.fromRGB(91, 87, 79),
		ride
	)
	console.Material = Enum.Material.Slate
	ride:PivotTo(SWING_PIVOT)
	return ride
end

-- Graybox pirate ship in the template's local frame: platform, two towers, and a box for the swinging ship.
local function buildGrayboxPirate(parkFolder: Folder): Model
	local ride = Instance.new("Model")
	ride.Name = PIRATE_NAME
	ride:SetAttribute("IsGraybox", true)
	ride.Parent = parkFolder

	local pivot = createPart("ParkPivot", Vector3.new(0.1, 0.1, 0.1), Vector3.zero, Color3.new(1, 1, 1), ride)
	pivot.Transparency = 1
	pivot.CanCollide = false
	pivot.CanTouch = false
	pivot.CanQuery = false
	pivot.CastShadow = false
	ride.PrimaryPart = pivot

	local scale = GameConfig.PirateScale
	local grey = Color3.fromRGB(112, 104, 94)
	local diameter = GameConfig.PiratePlatformRadius * 2 * scale
	local pad = createPart(
		"BasePad",
		Vector3.new(0.8, diameter, diameter),
		Vector3.new(0, 0.4, 0),
		grey,
		ride,
		Enum.Material.SmoothPlastic
	)
	pad.Shape = Enum.PartType.Cylinder
	pad.CFrame = CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.pi / 2)

	local hub = GameConfig.PirateHubHeight * scale
	for _, x in { -4.4, 4.4 } do
		for _, footZ in { -4.6, 4.6 } do
			local foot = Vector3.new(x * scale, 0.6, footZ * scale)
			local apex = Vector3.new(x * scale, hub, 0)
			local leg = createPart("Leg", Vector3.new(1.4, 1.4, (apex - foot).Magnitude), (foot + apex) / 2, grey, ride)
			leg.CFrame = CFrame.lookAt((foot + apex) / 2, apex)
		end
	end

	local center = Vector3.new(0, GameConfig.PirateShipCenterY, 0)
	local ship = createPart(
		"Ship",
		Vector3.new(6.8, 8.35, 12.54) * scale,
		Vector3.new(0, hub, 0) + center * scale,
		grey,
		ride,
		Enum.Material.SmoothPlastic
	)
	ship.CanCollide = false

	-- Off to the side of the platform, away from the queue that forms along the path to the west.
	local console = createPart(
		"PirateConsole",
		Vector3.new(2, 3, 2),
		Vector3.new(0, 1.5, diameter / 2 + 8),
		Color3.fromRGB(91, 87, 79),
		ride
	)
	console.Material = Enum.Material.Slate
	ride:PivotTo(PIRATE_PIVOT)
	return ride
end

-- Graybox haunted house in the template's local frame: a block with a roof and a round tower, plus the
-- invisible WindowLight markers HauntedService flickers.
local function buildGrayboxHaunted(parkFolder: Folder): Model
	local ride = Instance.new("Model")
	ride.Name = HAUNTED_NAME
	ride:SetAttribute("IsGraybox", true)
	ride.Parent = parkFolder

	local pivot = createPart("ParkPivot", Vector3.new(0.1, 0.1, 0.1), Vector3.zero, Color3.new(1, 1, 1), ride)
	pivot.Transparency = 1
	pivot.CanCollide = false
	pivot.CanTouch = false
	pivot.CanQuery = false
	pivot.CastShadow = false
	ride.PrimaryPart = pivot

	local scale = GameConfig.HauntedScale
	local grey = Color3.fromRGB(104, 112, 106)
	createPart("HouseBody", Vector3.new(12, 6, 9) * scale, Vector3.new(0, 3.6 * scale, 0), grey, ride)
	createPart(
		"Roof",
		Vector3.new(13, 3.4, 9.8) * scale,
		Vector3.new(0, 7.9 * scale, 0),
		Color3.fromRGB(96, 92, 88),
		ride
	)
	local tower = createPart(
		"Tower",
		Vector3.new(12, 3.6, 3.6) * scale,
		Vector3.new(5.4 * scale, 6.3 * scale, -1.5 * scale),
		grey,
		ride,
		Enum.Material.SmoothPlastic
	)
	tower.Shape = Enum.PartType.Cylinder
	tower.CFrame = CFrame.new(5.4 * scale, 6.3 * scale, -1.5 * scale) * CFrame.Angles(0, 0, math.pi / 2)
	for index, offset in
		{
			Vector3.new(-3.9, 2.9, -5.1),
			Vector3.new(3.9, 2.9, -5.1),
			Vector3.new(-3.9, 5.0, -5.1),
			Vector3.new(3.9, 5.0, -5.1),
		}
	do
		local light = createPart(
			string.format("WindowLight%d", index),
			Vector3.new(1.5, 1.5, 0.3) * scale,
			offset * scale,
			Color3.fromRGB(245, 193, 83),
			ride,
			Enum.Material.Neon
		)
		light.CanCollide = false
	end

	-- West of the house, away from the line that forms south of it.
	local console = createPart(
		"HauntedConsole",
		Vector3.new(2, 3, 2),
		Vector3.new(-9 * scale - 8, 1.5, -4 * scale),
		Color3.fromRGB(91, 87, 79),
		ride
	)
	console.Material = Enum.Material.Slate
	ride:PivotTo(HAUNTED_PIVOT)
	return ride
end

-- Graybox roller coaster: a chain of track segments along the generated centre line, a station slab, and
-- two boxes for the cars (CoasterService moves them).
local function buildGrayboxCoaster(parkFolder: Folder): Model
	local ride = Instance.new("Model")
	ride.Name = COASTER_NAME
	ride:SetAttribute("IsGraybox", true)
	ride.Parent = parkFolder

	local pivot = createPart("ParkPivot", Vector3.new(0.1, 0.1, 0.1), Vector3.zero, Color3.new(1, 1, 1), ride)
	pivot.Transparency = 1
	pivot.CanCollide = false
	pivot.CanTouch = false
	pivot.CanQuery = false
	pivot.CastShadow = false
	ride.PrimaryPart = pivot

	local scale = GameConfig.CoasterScale
	local grey = Color3.fromRGB(112, 104, 94)
	local points = CoasterPath.Points
	for index = 1, #points, 2 do
		local from = points[index] * scale
		local to = points[index % #points + 1 + 1 > #points and 1 or index + 2] * scale
		local length = (to - from).Magnitude
		if length > 0.1 then
			local segment = createPart(
				"TrackSegment",
				Vector3.new(1.6 * scale, 0.5 * scale, length + 0.3),
				(from + to) / 2,
				grey,
				ride
			)
			segment.CFrame = CFrame.lookAt((from + to) / 2, to)
			segment.CanCollide = false
		end
	end
	createPart("Station", Vector3.new(20, 0.7, 4.4) * scale, Vector3.new(0, 0.35 * scale, -8 * scale), grey, ride)

	local cars = Instance.new("Model")
	cars.Name = "CoasterCars"
	cars.Parent = ride
	for index = 1, GameConfig.CoasterCarCount do
		local car = createPart(
			string.format("CoasterCar%d", index),
			Vector3.new(2.2, 1.59, 3.96) * scale,
			points[CoasterPath.StationIndex] * scale,
			grey,
			cars,
			Enum.Material.SmoothPlastic
		)
		car.CanCollide = false
		car.CanTouch = false
		car.CanQuery = false
	end

	-- West of the station, away from the line that forms south of it.
	local console = createPart(
		"CoasterConsole",
		Vector3.new(2, 3, 2),
		Vector3.new(-15 * scale, 1.5, -10 * scale),
		Color3.fromRGB(91, 87, 79),
		ride
	)
	console.Material = Enum.Material.Slate
	ride:PivotTo(COASTER_PIVOT)
	return ride
end

local function ensureRidePrompt(
	console: BasePart,
	name: string,
	actionText: string,
	holdDuration: number,
	objectText: string,
	keyCode: Enum.KeyCode?,
	uiOffset: Vector2?
): ProximityPrompt
	local existing = console:FindFirstChild(name)
	local prompt: ProximityPrompt
	if existing == nil then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = name
		prompt.Parent = console
	elseif existing:IsA("ProximityPrompt") then
		prompt = existing
	else
		error(string.format("[ParkPark] %s.%s must be a ProximityPrompt", console.Name, name))
	end

	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = holdDuration
	-- Consoles are scaled up with their rides, so their prompts reach further than the small ones did.
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = keyCode or Enum.KeyCode.E
	prompt.UIOffset = uiOffset or Vector2.zero
	prompt.Enabled = false
	return prompt
end

-- Income and staff upgrades appear once a ride is repaired; RideService fills in their live text.
local function ensureUpgradePrompts(console: BasePart, objectText: string): (ProximityPrompt, ProximityPrompt)
	local income = ensureRidePrompt(
		console,
		"IncomePrompt",
		"요금 올리기",
		0.6,
		objectText,
		Enum.KeyCode.E,
		Vector2.new(0, -70)
	)
	local staff =
		ensureRidePrompt(console, "StaffPrompt", "직원 고용", 0.6, objectText, Enum.KeyCode.F, Vector2.zero)
	return income, staff
end

local function getOrCreateParkFolder(): Folder
	local existing = Workspace:FindFirstChild(PARK_FOLDER_NAME)
	if existing ~= nil then
		if not existing:IsA("Folder") then
			error("[ParkPark] Workspace.ParkParkWorld must be a Folder")
		end
		return existing
	end

	local parkFolder = Instance.new("Folder")
	parkFolder.Name = PARK_FOLDER_NAME
	parkFolder.Parent = Workspace
	return parkFolder
end

local function getOrCreateModel(parent: Instance, name: string, build: (Folder) -> Model): Model
	local existing = parent:FindFirstChild(name)
	if existing ~= nil then
		if not existing:IsA("Model") then
			error(string.format("[ParkPark] %s.%s must be a Model", parent:GetFullName(), name))
		end
		return existing
	end

	if not parent:IsA("Folder") then
		error("[ParkPark] Expected park folder while creating " .. name)
	end

	local template = findAuthoredTemplate(name)
	if template then
		local model = template:Clone()
		model.Name = name
		model:SetAttribute("IsGraybox", false)
		model.Parent = parent
		if name == ENTRANCE_NAME then
			model:PivotTo(AUTHORED_ENTRANCE_PIVOT)
		elseif name == CAROUSEL_NAME then
			model:PivotTo(AUTHORED_CAROUSEL_PIVOT)
		elseif name == TEACUPS_NAME then
			model:PivotTo(AUTHORED_TEACUPS_PIVOT)
		elseif name == BUMPER_NAME then
			model:PivotTo(AUTHORED_BUMPER_PIVOT)
		elseif name == SNACK_NAME then
			model:PivotTo(AUTHORED_SNACK_PIVOT)
		elseif name == FERRIS_NAME then
			model:PivotTo(FERRIS_PIVOT)
		elseif name == SWING_NAME then
			model:PivotTo(SWING_PIVOT)
		elseif name == PIRATE_NAME then
			model:PivotTo(PIRATE_PIVOT)
		elseif name == HAUNTED_NAME then
			model:PivotTo(HAUNTED_PIVOT)
		elseif name == COASTER_NAME then
			model:PivotTo(COASTER_PIVOT)
		end
		return model
	end

	return build(parent)
end

function ParkBuilder.Build(): References
	hideDefaultBaseplate()
	positionGrayboxSpawn()

	local parkFolder = getOrCreateParkFolder()
	local entrance = getOrCreateModel(parkFolder, ENTRANCE_NAME, buildGrayboxEntrance)
	ensureGrayboxApproach(parkFolder)
	local gateRope, gatePrompt = ensureGate(parkFolder)
	if entrance:GetAttribute("IsGraybox") == nil then
		entrance:SetAttribute("IsGraybox", true)
	end
	ensureAuthoredEntranceSign(entrance)
	local debris, cleanupTarget, cleanupPrompt = ensureGrayboxDebris(entrance)
	if parkFolder:GetAttribute("EntranceCleared") == nil then
		parkFolder:SetAttribute("EntranceCleared", false)
	end
	if parkFolder:GetAttribute("EntranceCleared") == true then
		for _, descendant in debris:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Transparency = 1
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
			end
		end
	end
	applyAuthoredEntranceState(entrance, parkFolder:GetAttribute("EntranceCleared") == true)
	local carousel = getOrCreateModel(parkFolder, CAROUSEL_NAME, buildGrayboxCarousel)
	if carousel:GetAttribute("IsGraybox") == nil then
		carousel:SetAttribute("IsGraybox", true)
	end
	if carousel:GetAttribute("IsRepaired") == nil then
		carousel:SetAttribute("IsRepaired", false)
	end
	if carousel:GetAttribute("IsOperating") == nil then
		carousel:SetAttribute("IsOperating", false)
	end
	local rotorInstance = carousel:FindFirstChild("CarouselRotor")
	local rotorModel: Model
	if rotorInstance == nil then
		local newRotor = Instance.new("Model")
		newRotor.Name = "CarouselRotor"
		newRotor.Parent = carousel
		for _, partName in
			{
				"CenterPost",
				"DamagedCanopy",
				"CanopySupport",
				"BrokenSeatA",
				"BrokenSeatB",
				"BrokenSeatC",
				"BrokenSeatD",
			}
		do
			local part = carousel:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				part.Parent = newRotor
			end
		end
		rotorModel = newRotor
	elseif rotorInstance:IsA("Model") then
		rotorModel = rotorInstance
	else
		error("[ParkPark] BrokenCarousel.CarouselRotor must be a Model")
	end
	local rotor = prepareCarouselRotor(rotorModel)

	local console = carousel:FindFirstChild("RepairConsole")
	if console == nil or not console:IsA("BasePart") then
		error("[ParkPark] BrokenCarousel.RepairConsole must be a BasePart")
	end

	local prompt = console:FindFirstChild("RepairPrompt")
	local repairPrompt: ProximityPrompt
	if prompt == nil then
		repairPrompt = Instance.new("ProximityPrompt")
		repairPrompt.Name = "RepairPrompt"
		repairPrompt.ActionText = "수리하기"
		repairPrompt.ObjectText = "고장 난 회전목마"
		repairPrompt.HoldDuration = 2
		repairPrompt.MaxActivationDistance = 18
		repairPrompt.RequiresLineOfSight = false
		repairPrompt.Enabled = parkFolder:GetAttribute("EntranceCleared") == true
		repairPrompt.Parent = console
	elseif prompt:IsA("ProximityPrompt") then
		repairPrompt = prompt
	else
		error("[ParkPark] BrokenCarousel.RepairConsole.RepairPrompt must be a ProximityPrompt")
	end
	local carouselIncomePrompt, carouselStaffPrompt = ensureUpgradePrompts(console, "회전목마")
	if carousel:GetAttribute("IsGraybox") ~= true then
		applyAuthoredCarouselState(carousel, carousel:GetAttribute("IsRepaired") == true)
	end

	local teacupsRide = getOrCreateModel(parkFolder, TEACUPS_NAME, buildGrayboxTeacups)
	if teacupsRide:GetAttribute("IsGraybox") == nil then
		teacupsRide:SetAttribute("IsGraybox", true)
	end
	if teacupsRide:GetAttribute("IsUnlocked") == nil then
		teacupsRide:SetAttribute("IsUnlocked", false)
	end
	if teacupsRide:GetAttribute("IsRepaired") == nil then
		teacupsRide:SetAttribute("IsRepaired", false)
	end
	if teacupsRide:GetAttribute("IsOperating") == nil then
		teacupsRide:SetAttribute("IsOperating", false)
	end
	local teacupsRotorInstance = teacupsRide:FindFirstChild("TeacupsRotor")
	if teacupsRotorInstance == nil or not teacupsRotorInstance:IsA("Model") then
		error("[ParkPark] TeacupsRide.TeacupsRotor must be a Model")
	end
	local teacupsRotor = prepareTeacupsRotor(teacupsRotorInstance)
	local teacupsConsoleInstance = teacupsRide:FindFirstChild("TeacupsConsole")
	if teacupsConsoleInstance == nil or not teacupsConsoleInstance:IsA("BasePart") then
		error("[ParkPark] TeacupsRide.TeacupsConsole must be a BasePart")
	end
	local unlockPrompt =
		ensureRidePrompt(teacupsConsoleInstance, "UnlockPrompt", "해금하기", 1.5, "찻잔 라이드", nil, nil)
	local teacupsRepairPrompt =
		ensureRidePrompt(teacupsConsoleInstance, "RepairPrompt", "수리하기", 2, "찻잔 라이드", nil, nil)
	local teacupsIncomePrompt, teacupsStaffPrompt = ensureUpgradePrompts(teacupsConsoleInstance, "찻잔 라이드")
	-- Spinning cups are a separate model; they are driven by TeacupService and never welded to the rotor.
	local teacupCupsInstance = teacupsRide:FindFirstChild("TeacupCups")
	local teacupCups: Model? = nil
	if teacupCupsInstance and teacupCupsInstance:IsA("Model") then
		teacupCups = teacupCupsInstance
		for _, descendant in teacupCupsInstance:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
			end
		end
	end
	applyTeacupsAppearance(teacupsRide, teacupsRide:GetAttribute("IsRepaired") == true)

	local bumperRide = getOrCreateModel(parkFolder, BUMPER_NAME, buildGrayboxBumperCars)
	if bumperRide:GetAttribute("IsGraybox") == nil then
		bumperRide:SetAttribute("IsGraybox", true)
	end
	for _, attribute in { "IsUnlocked", "IsRepaired", "IsOperating" } do
		if bumperRide:GetAttribute(attribute) == nil then
			bumperRide:SetAttribute(attribute, false)
		end
	end
	local bumperCarsInstance = bumperRide:FindFirstChild("BumperCars")
	if bumperCarsInstance == nil or not bumperCarsInstance:IsA("Model") then
		error("[ParkPark] BumperCarsRide.BumperCars must be a Model")
	end
	-- Cars are driven by the server each frame, so they stay anchored and are never welded together.
	for _, descendant in bumperCarsInstance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	local bumperConsoleInstance = bumperRide:FindFirstChild("BumperConsole")
	if bumperConsoleInstance == nil or not bumperConsoleInstance:IsA("BasePart") then
		error("[ParkPark] BumperCarsRide.BumperConsole must be a BasePart")
	end
	local bumperUnlockPrompt =
		ensureRidePrompt(bumperConsoleInstance, "UnlockPrompt", "해금하기", 1.5, "범퍼카", nil, nil)
	local bumperRepairPrompt =
		ensureRidePrompt(bumperConsoleInstance, "RepairPrompt", "수리하기", 2, "범퍼카", nil, nil)
	local bumperIncomePrompt, bumperStaffPrompt = ensureUpgradePrompts(bumperConsoleInstance, "범퍼카")
	applyBumperAppearance(bumperRide, bumperRide:GetAttribute("IsRepaired") == true)

	local snackStand = getOrCreateModel(parkFolder, SNACK_NAME, buildGrayboxSnackStand)
	if snackStand:GetAttribute("IsGraybox") == nil then
		snackStand:SetAttribute("IsGraybox", true)
	end
	for _, attribute in { "IsUnlocked", "IsRepaired", "IsOperating" } do
		if snackStand:GetAttribute(attribute) == nil then
			snackStand:SetAttribute(attribute, false)
		end
	end
	local snackCounterInstance = snackStand:FindFirstChild("SnackCounter", true)
	if snackCounterInstance == nil or not snackCounterInstance:IsA("BasePart") then
		error("[ParkPark] SnackStand.SnackCounter must be a BasePart")
	end
	local snackConsoleInstance = snackStand:FindFirstChild("SnackConsole", true)
	if snackConsoleInstance == nil or not snackConsoleInstance:IsA("BasePart") then
		error("[ParkPark] SnackStand.SnackConsole must be a BasePart")
	end
	local snackUnlockPrompt =
		ensureRidePrompt(snackConsoleInstance, "UnlockPrompt", "해금하기", 1.5, "간식 판매대", nil, nil)
	local snackRepairPrompt =
		ensureRidePrompt(snackConsoleInstance, "RepairPrompt", "수리하기", 2, "간식 판매대", nil, nil)
	local snackIncomePrompt, snackStaffPrompt = ensureUpgradePrompts(snackConsoleInstance, "간식 판매대")
	applySnackAppearance(snackStand, snackStand:GetAttribute("IsRepaired") == true)

	local ferrisRide = getOrCreateModel(parkFolder, FERRIS_NAME, buildGrayboxFerris)
	if ferrisRide:GetAttribute("IsGraybox") == nil then
		ferrisRide:SetAttribute("IsGraybox", true)
	end
	for _, attribute in { "IsUnlocked", "IsRepaired", "IsOperating" } do
		if ferrisRide:GetAttribute(attribute) == nil then
			ferrisRide:SetAttribute(attribute, false)
		end
	end
	local ferrisWheelInstance = ferrisRide:FindFirstChild("Wheel", true)
	if ferrisWheelInstance == nil or not ferrisWheelInstance:IsA("BasePart") then
		error("[ParkPark] FerrisWheelRide.Wheel must be a BasePart")
	end
	local ferrisCabinsInstance = ferrisRide:FindFirstChild("FerrisCabins", true)
	if ferrisCabinsInstance == nil or not ferrisCabinsInstance:IsA("Model") then
		error("[ParkPark] FerrisWheelRide.FerrisCabins must be a Model")
	end
	-- The wheel and its cabins are driven by FerrisService each frame, so they stay anchored and non-solid.
	ferrisWheelInstance.Anchored = true
	ferrisWheelInstance.CanCollide = false
	ferrisWheelInstance.CanTouch = false
	ferrisWheelInstance.CanQuery = false
	for _, descendant in ferrisCabinsInstance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	local ferrisConsoleInstance = ferrisRide:FindFirstChild("FerrisConsole", true)
	if ferrisConsoleInstance == nil or not ferrisConsoleInstance:IsA("BasePart") then
		error("[ParkPark] FerrisWheelRide.FerrisConsole must be a BasePart")
	end
	local ferrisUnlockPrompt =
		ensureRidePrompt(ferrisConsoleInstance, "UnlockPrompt", "해금하기", 1.5, "관람차", nil, nil)
	local ferrisRepairPrompt =
		ensureRidePrompt(ferrisConsoleInstance, "RepairPrompt", "수리하기", 2, "관람차", nil, nil)
	local ferrisIncomePrompt, ferrisStaffPrompt = ensureUpgradePrompts(ferrisConsoleInstance, "관람차")
	applyFerrisAppearance(ferrisRide, ferrisRide:GetAttribute("IsRepaired") == true)

	local swingRide = getOrCreateModel(parkFolder, SWING_NAME, buildGrayboxSwing)
	if swingRide:GetAttribute("IsGraybox") == nil then
		swingRide:SetAttribute("IsGraybox", true)
	end
	for _, attribute in { "IsUnlocked", "IsRepaired", "IsOperating" } do
		if swingRide:GetAttribute(attribute) == nil then
			swingRide:SetAttribute(attribute, false)
		end
	end
	local swingCrownInstance = swingRide:FindFirstChild("Crown", true)
	if swingCrownInstance == nil or not swingCrownInstance:IsA("BasePart") then
		error("[ParkPark] SwingRide.Crown must be a BasePart")
	end
	local swingSeatsInstance = swingRide:FindFirstChild("SwingSeats", true)
	if swingSeatsInstance == nil or not swingSeatsInstance:IsA("Model") then
		error("[ParkPark] SwingRide.SwingSeats must be a Model")
	end
	-- SwingService moves the crown and the seats every frame, so they stay anchored and non-solid.
	swingCrownInstance.Anchored = true
	swingCrownInstance.CanCollide = false
	swingCrownInstance.CanTouch = false
	swingCrownInstance.CanQuery = false
	for _, descendant in swingSeatsInstance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	local swingConsoleInstance = swingRide:FindFirstChild("SwingConsole", true)
	if swingConsoleInstance == nil or not swingConsoleInstance:IsA("BasePart") then
		error("[ParkPark] SwingRide.SwingConsole must be a BasePart")
	end
	local swingUnlockPrompt =
		ensureRidePrompt(swingConsoleInstance, "UnlockPrompt", "해금하기", 1.5, "회전 그네", nil, nil)
	local swingRepairPrompt =
		ensureRidePrompt(swingConsoleInstance, "RepairPrompt", "수리하기", 2, "회전 그네", nil, nil)
	local swingIncomePrompt, swingStaffPrompt = ensureUpgradePrompts(swingConsoleInstance, "회전 그네")
	applySwingAppearance(swingRide, swingRide:GetAttribute("IsRepaired") == true)

	local pirateRide = getOrCreateModel(parkFolder, PIRATE_NAME, buildGrayboxPirate)
	if pirateRide:GetAttribute("IsGraybox") == nil then
		pirateRide:SetAttribute("IsGraybox", true)
	end
	for _, attribute in { "IsUnlocked", "IsRepaired", "IsOperating" } do
		if pirateRide:GetAttribute(attribute) == nil then
			pirateRide:SetAttribute(attribute, false)
		end
	end
	local pirateShipInstance = pirateRide:FindFirstChild("Ship", true)
	if pirateShipInstance == nil or not pirateShipInstance:IsA("BasePart") then
		error("[ParkPark] PirateRide.Ship must be a BasePart")
	end
	-- PirateService swings the ship every frame, so it stays anchored and non-solid.
	pirateShipInstance.Anchored = true
	pirateShipInstance.CanCollide = false
	pirateShipInstance.CanTouch = false
	pirateShipInstance.CanQuery = false
	local pirateConsoleInstance = pirateRide:FindFirstChild("PirateConsole", true)
	if pirateConsoleInstance == nil or not pirateConsoleInstance:IsA("BasePart") then
		error("[ParkPark] PirateRide.PirateConsole must be a BasePart")
	end
	applyPirateAppearance(pirateRide, pirateRide:GetAttribute("IsRepaired") == true)

	local hauntedHouse = getOrCreateModel(parkFolder, HAUNTED_NAME, buildGrayboxHaunted)
	if hauntedHouse:GetAttribute("IsGraybox") == nil then
		hauntedHouse:SetAttribute("IsGraybox", true)
	end
	for _, attribute in { "IsUnlocked", "IsRepaired", "IsOperating" } do
		if hauntedHouse:GetAttribute(attribute) == nil then
			hauntedHouse:SetAttribute(attribute, false)
		end
	end
	local hauntedBodyInstance = hauntedHouse:FindFirstChild("HouseBody", true)
	if hauntedBodyInstance == nil or not hauntedBodyInstance:IsA("BasePart") then
		error("[ParkPark] HauntedHouse.HouseBody must be a BasePart")
	end
	local hauntedConsoleInstance = hauntedHouse:FindFirstChild("HauntedConsole", true)
	if hauntedConsoleInstance == nil or not hauntedConsoleInstance:IsA("BasePart") then
		error("[ParkPark] HauntedHouse.HauntedConsole must be a BasePart")
	end
	applyHauntedAppearance(hauntedHouse, hauntedHouse:GetAttribute("IsRepaired") == true)

	local coasterRide = getOrCreateModel(parkFolder, COASTER_NAME, buildGrayboxCoaster)
	if coasterRide:GetAttribute("IsGraybox") == nil then
		coasterRide:SetAttribute("IsGraybox", true)
	end
	for _, attribute in { "IsUnlocked", "IsRepaired", "IsOperating" } do
		if coasterRide:GetAttribute(attribute) == nil then
			coasterRide:SetAttribute(attribute, false)
		end
	end
	local coasterCarsInstance = coasterRide:FindFirstChild("CoasterCars", true)
	if coasterCarsInstance == nil or not coasterCarsInstance:IsA("Model") then
		error("[ParkPark] CoasterRide.CoasterCars must be a Model")
	end
	-- CoasterService moves the cars every frame, so they stay anchored and non-solid.
	for _, descendant in coasterCarsInstance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	local coasterConsoleInstance = coasterRide:FindFirstChild("CoasterConsole", true)
	if coasterConsoleInstance == nil or not coasterConsoleInstance:IsA("BasePart") then
		error("[ParkPark] CoasterRide.CoasterConsole must be a BasePart")
	end
	applyCoasterAppearance(coasterRide, coasterRide:GetAttribute("IsRepaired") == true)

	return {
		ParkFolder = parkFolder,
		Entrance = entrance,
		Debris = debris,
		CleanupTarget = cleanupTarget,
		CleanupPrompt = cleanupPrompt,
		Carousel = carousel,
		CarouselRotor = rotor,
		RepairConsole = console,
		RepairPrompt = repairPrompt,
		CarouselIncomePrompt = carouselIncomePrompt,
		CarouselStaffPrompt = carouselStaffPrompt,
		TeacupsRide = teacupsRide,
		TeacupsRotor = teacupsRotor,
		TeacupCups = teacupCups,
		TeacupsConsole = teacupsConsoleInstance,
		TeacupsUnlockPrompt = unlockPrompt,
		TeacupsRepairPrompt = teacupsRepairPrompt,
		TeacupsIncomePrompt = teacupsIncomePrompt,
		TeacupsStaffPrompt = teacupsStaffPrompt,
		BumperRide = bumperRide,
		BumperCars = bumperCarsInstance,
		BumperConsole = bumperConsoleInstance,
		BumperUnlockPrompt = bumperUnlockPrompt,
		BumperRepairPrompt = bumperRepairPrompt,
		BumperIncomePrompt = bumperIncomePrompt,
		BumperStaffPrompt = bumperStaffPrompt,
		SnackStand = snackStand,
		SnackCounter = snackCounterInstance,
		SnackConsole = snackConsoleInstance,
		SnackUnlockPrompt = snackUnlockPrompt,
		SnackRepairPrompt = snackRepairPrompt,
		SnackIncomePrompt = snackIncomePrompt,
		SnackStaffPrompt = snackStaffPrompt,
		FerrisRide = ferrisRide,
		FerrisWheel = ferrisWheelInstance,
		FerrisCabins = ferrisCabinsInstance,
		FerrisConsole = ferrisConsoleInstance,
		FerrisUnlockPrompt = ferrisUnlockPrompt,
		FerrisRepairPrompt = ferrisRepairPrompt,
		FerrisIncomePrompt = ferrisIncomePrompt,
		FerrisStaffPrompt = ferrisStaffPrompt,
		SwingRide = swingRide,
		SwingCrown = swingCrownInstance,
		SwingSeats = swingSeatsInstance,
		SwingConsole = swingConsoleInstance,
		SwingUnlockPrompt = swingUnlockPrompt,
		SwingRepairPrompt = swingRepairPrompt,
		SwingIncomePrompt = swingIncomePrompt,
		SwingStaffPrompt = swingStaffPrompt,
		PirateRide = pirateRide,
		PirateShip = pirateShipInstance,
		PirateConsole = pirateConsoleInstance,
		HauntedHouse = hauntedHouse,
		HauntedBody = hauntedBodyInstance,
		HauntedConsole = hauntedConsoleInstance,
		CoasterRide = coasterRide,
		CoasterCars = coasterCarsInstance,
		CoasterConsole = coasterConsoleInstance,
		GateRope = gateRope,
		GatePrompt = gatePrompt,
	}
end

-- The authored litter model, or nil while it has not been imported (LitterService then builds a graybox one).
function ParkBuilder.FindLitterTemplate(): Model?
	local folder = getAssetFolder()
	local name = assetManifest.Models.Litter
	if folder == nil or name == nil then
		return nil
	end
	local template = folder:FindFirstChild(name)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

function ParkBuilder.ApplyEntranceRestored(entrance: Model)
	applyAuthoredEntranceState(entrance, true)
end

-- Graybox rides use a temporary tint swap; authored rides toggle their canopy meshes.
function ParkBuilder.ApplyRepairedAppearance(carousel: Model)
	if carousel:GetAttribute("IsGraybox") ~= true then
		applyAuthoredCarouselState(carousel, true)
		return
	end

	for _, descendant in carousel:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Material = Enum.Material.SmoothPlastic
			if descendant.Name == "RidePlatform" then
				descendant.Color = Color3.fromRGB(80, 170, 110)
			elseif descendant.Name == "DamagedCanopy" then
				descendant.Color = Color3.fromRGB(235, 190, 70)
			else
				descendant.Color = Color3.fromRGB(190, 90, 85)
			end
		end
	end
end

function ParkBuilder.ApplyTeacupsRepairedAppearance(ride: Model)
	applyTeacupsAppearance(ride, true)
end

function ParkBuilder.ApplyBumperRepairedAppearance(ride: Model)
	applyBumperAppearance(ride, true)
end

function ParkBuilder.ApplySnackRepairedAppearance(stand: Model)
	applySnackAppearance(stand, true)
end

function ParkBuilder.ApplyFerrisRepairedAppearance(ride: Model)
	applyFerrisAppearance(ride, true)
end

function ParkBuilder.ApplySwingRepairedAppearance(ride: Model)
	applySwingAppearance(ride, true)
end

function ParkBuilder.ApplyPirateRepairedAppearance(ride: Model)
	applyPirateAppearance(ride, true)
end

function ParkBuilder.ApplyHauntedRepairedAppearance(ride: Model)
	applyHauntedAppearance(ride, true)
end

function ParkBuilder.ApplyCoasterRepairedAppearance(ride: Model)
	applyCoasterAppearance(ride, true)
end

return ParkBuilder
