--!strict

local Workspace = game:GetService("Workspace")

local PARK_FOLDER_NAME = "ParkParkWorld"
local ENTRANCE_NAME = "RuinedEntrance"
local CAROUSEL_NAME = "BrokenCarousel"

local ParkBuilder = {}

export type References = {
	ParkFolder: Folder,
	Entrance: Model,
	Carousel: Model,
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

local function buildGrayboxEntrance(parkFolder: Folder): Model
	local entrance = Instance.new("Model")
	entrance.Name = ENTRANCE_NAME
	entrance.Parent = parkFolder

	createPart(
		"EntranceGround",
		Vector3.new(70, 1, 60),
		Vector3.new(0, -0.5, 10),
		Color3.fromRGB(95, 95, 90),
		parkFolder
	)
	createPart("LeftPillar", Vector3.new(4, 14, 4), Vector3.new(-16, 7, 25), Color3.fromRGB(105, 105, 100), entrance)
	createPart("RightPillar", Vector3.new(4, 14, 4), Vector3.new(16, 7, 25), Color3.fromRGB(105, 105, 100), entrance)

	local beam =
		createPart("BrokenArch", Vector3.new(36, 3, 4), Vector3.new(0, 13, 25), Color3.fromRGB(80, 80, 76), entrance)
	local sign = Instance.new("SurfaceGui")
	sign.Name = "EntranceSign"
	sign.Face = Enum.NormalId.Front
	sign.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sign.PixelsPerStud = 40
	sign.Parent = beam

	local label = Instance.new("TextLabel")
	label.Name = "SignText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	label.BackgroundTransparency = 0.1
	label.Text = "PARK PARK"
	label.TextColor3 = Color3.fromRGB(220, 220, 220)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = sign

	createPart(
		"CrackedPath",
		Vector3.new(14, 0.2, 20),
		Vector3.new(0, 0.1, 11),
		Color3.fromRGB(115, 112, 104),
		parkFolder
	)

	return entrance
end

local function buildGrayboxCarousel(parkFolder: Folder): Model
	local carousel = Instance.new("Model")
	carousel.Name = CAROUSEL_NAME
	carousel.Parent = parkFolder

	createPart("RidePlatform", Vector3.new(22, 1, 22), Vector3.new(0, 0.5, -12), Color3.fromRGB(90, 90, 90), carousel)
	createPart("CenterPost", Vector3.new(2, 11, 2), Vector3.new(0, 6, -12), Color3.fromRGB(75, 75, 72), carousel)
	createPart("DamagedCanopy", Vector3.new(18, 1, 18), Vector3.new(0, 11, -12), Color3.fromRGB(80, 80, 76), carousel)
	createPart("CanopySupport", Vector3.new(20, 0.7, 1), Vector3.new(0, 10, -12), Color3.fromRGB(65, 65, 63), carousel)
	createPart("BrokenSeatA", Vector3.new(3, 2, 3), Vector3.new(7, 2, -12), Color3.fromRGB(105, 105, 100), carousel)
	createPart("BrokenSeatB", Vector3.new(3, 2, 3), Vector3.new(-7, 2, -12), Color3.fromRGB(105, 105, 100), carousel)
	createPart("BrokenSeatC", Vector3.new(3, 2, 3), Vector3.new(0, 2, -19), Color3.fromRGB(105, 105, 100), carousel)
	createPart("BrokenSeatD", Vector3.new(3, 2, 3), Vector3.new(0, 2, -5), Color3.fromRGB(105, 105, 100), carousel)

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
	return build(parent)
end

function ParkBuilder.Build(): References
	local parkFolder = getOrCreateParkFolder()
	local entrance = getOrCreateModel(parkFolder, ENTRANCE_NAME, buildGrayboxEntrance)
	local carousel = getOrCreateModel(parkFolder, CAROUSEL_NAME, buildGrayboxCarousel)

	local console = carousel:FindFirstChild("RepairConsole")
	if console == nil or not console:IsA("BasePart") then
		error("[ParkPark] BrokenCarousel.RepairConsole must be a BasePart")
	end

	local prompt = console:FindFirstChild("RepairPrompt")
	if prompt == nil or not prompt:IsA("ProximityPrompt") then
		error("[ParkPark] BrokenCarousel.RepairConsole.RepairPrompt must be a ProximityPrompt")
	end

	return {
		ParkFolder = parkFolder,
		Entrance = entrance,
		Carousel = carousel,
		RepairConsole = console,
		RepairPrompt = prompt,
	}
end

-- This color swap belongs to the temporary graybox and must be replaced by
-- authored carousel state assets before the slice is presented as final art.
function ParkBuilder.ApplyRepairedGrayboxAppearance(carousel: Model)
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
