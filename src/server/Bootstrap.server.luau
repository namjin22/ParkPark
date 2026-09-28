--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local PARK_FOLDER_NAME = "ParkParkWorld"
local CAROUSEL_NAME = "BrokenCarousel"
local ENTRANCE_NAME = "RuinedEntrance"

local parkFolderInstance = Workspace:FindFirstChild(PARK_FOLDER_NAME)
if parkFolderInstance and not parkFolderInstance:IsA("Folder") then
	error("[ParkPark] Workspace.ParkParkWorld must be a Folder")
end

local parkFolder = (parkFolderInstance or Instance.new("Folder")) :: Folder
if parkFolderInstance == nil then
	parkFolder.Name = PARK_FOLDER_NAME
	parkFolder.Parent = Workspace
end

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

local function createSign(beam: BasePart)
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
end

if parkFolder:FindFirstChild(ENTRANCE_NAME) == nil then
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
	createSign(beam)
	createPart(
		"CrackedPath",
		Vector3.new(14, 0.2, 20),
		Vector3.new(0, 0.1, 11),
		Color3.fromRGB(115, 112, 104),
		parkFolder
	)
end

if parkFolder:FindFirstChild(CAROUSEL_NAME) == nil then
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
end

local carouselModel = parkFolder:WaitForChild(CAROUSEL_NAME) :: Model
local repairConsole = carouselModel:WaitForChild("RepairConsole") :: BasePart
local repairPrompt = repairConsole:WaitForChild("RepairPrompt") :: ProximityPrompt
local rewardedPlayers: { [number]: boolean } = {}
local carouselRepaired = false

local function setupPlayer(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats == nil then
		local newLeaderstats = Instance.new("Folder")
		newLeaderstats.Name = "leaderstats"
		newLeaderstats.Parent = player
		leaderstats = newLeaderstats
	end

	if leaderstats == nil or not leaderstats:IsA("Folder") then
		warn("[ParkPark] Could not initialize leaderstats for " .. player.Name)
		return
	end

	local tickets = leaderstats:FindFirstChild("Tickets")
	if tickets == nil then
		local ticketValue = Instance.new("IntValue")
		ticketValue.Name = "Tickets"
		ticketValue.Value = GameConfig.StartingTickets
		ticketValue.Parent = leaderstats
	end
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
	setupPlayer(player)
end

repairPrompt.Triggered:Connect(function(player: Player)
	if player.Parent ~= Players or rewardedPlayers[player.UserId] then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or rootPart == nil or not rootPart:IsA("BasePart") then
		return
	end
	if (rootPart.Position - repairConsole.Position).Magnitude > repairPrompt.MaxActivationDistance + 2 then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local tickets = leaderstats and leaderstats:FindFirstChild("Tickets")
	if tickets == nil or not tickets:IsA("IntValue") then
		return
	end

	-- The carousel is shared in this prototype, while each player can claim the repair reward only once.
	rewardedPlayers[player.UserId] = true
	if not carouselRepaired then
		carouselRepaired = true
		for _, descendant in carouselModel:GetDescendants() do
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
		repairPrompt.ActionText = "수리 완료"
	end

	tickets.Value += GameConfig.CarouselRepairReward
end)

print("[ParkPark] Server bootstrap loaded")
