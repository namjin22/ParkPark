--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PARK_FOLDER_NAME = "ParkParkWorld"
local ENTRANCE_NAME = "RuinedEntrance"
local CAROUSEL_NAME = "BrokenCarousel"
local assetFolder = ReplicatedStorage:WaitForChild("ParkParkAssets")
local assetManifest = require(assetFolder:WaitForChild("AssetManifest"))

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

local function createEntranceSign(panel: BasePart)
	if panel:FindFirstChild("EntranceSign") then
		return
	end

	local sign = Instance.new("SurfaceGui")
	sign.Name = "EntranceSign"
	sign.Face = Enum.NormalId.Front
	sign.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sign.PixelsPerStud = 60
	sign.Parent = panel

	local label = Instance.new("TextLabel")
	label.Name = "SignText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "PARK PARK"
	label.TextColor3 = Color3.fromRGB(255, 241, 210)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = sign
end

local function ensureGrayboxApproach(parkFolder: Folder)
	if parkFolder:FindFirstChild("EntranceGround") == nil then
		createPart(
			"EntranceGround",
			Vector3.new(70, 1, 60),
			Vector3.new(0, -0.5, 10),
			Color3.fromRGB(95, 95, 90),
			parkFolder
		)
	end
	if parkFolder:FindFirstChild("CrackedPath") == nil then
		createPart(
			"CrackedPath",
			Vector3.new(14, 0.2, 20),
			Vector3.new(0, 0.1, 11),
			Color3.fromRGB(115, 112, 104),
			parkFolder
		)
	end
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

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CleanupPrompt"
	prompt.ActionText = "잔해 치우기"
	prompt.ObjectText = "입구 잔해"
	prompt.HoldDuration = 1.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = target

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
	createEntranceSign(arch)
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

local function findAuthoredTemplate(name: string): Model?
	local assetName: string?
	if name == ENTRANCE_NAME then
		assetName = assetManifest.Models.Entrance
	elseif name == CAROUSEL_NAME then
		assetName = assetManifest.Models.Carousel
	end

	if assetName == nil then
		return nil
	end

	local template = assetFolder:FindFirstChild(assetName)
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
end

local function ensureGrayboxDebris(entrance: Model): (Model, BasePart, ProximityPrompt)
	local debrisInstance = entrance:FindFirstChild("EntranceDebris")
	local debris: Model
	if debrisInstance == nil then
		debris = buildGrayboxDebris(entrance)
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
		createEntranceSign(panel)
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
			model:PivotTo(CFrame.new(0, 0, 25))
		elseif name == CAROUSEL_NAME then
			model:PivotTo(CFrame.new(0, 0, -12))
		end
		return model
	end

	return build(parent)
end

function ParkBuilder.Build(): References
	local parkFolder = getOrCreateParkFolder()
	local entrance = getOrCreateModel(parkFolder, ENTRANCE_NAME, buildGrayboxEntrance)
	ensureGrayboxApproach(parkFolder)
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
		repairPrompt.MaxActivationDistance = 10
		repairPrompt.RequiresLineOfSight = false
		repairPrompt.Enabled = parkFolder:GetAttribute("EntranceCleared") == true
		repairPrompt.Parent = console
	elseif prompt:IsA("ProximityPrompt") then
		repairPrompt = prompt
	else
		error("[ParkPark] BrokenCarousel.RepairConsole.RepairPrompt must be a ProximityPrompt")
	end
	if carousel:GetAttribute("IsGraybox") ~= true then
		applyAuthoredCarouselState(carousel, carousel:GetAttribute("IsRepaired") == true)
	end

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
	}
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

return ParkBuilder
