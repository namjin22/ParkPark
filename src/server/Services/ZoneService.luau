--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Builds each zone beyond the first park (GameConfig.ZoneOrder): its ground, the road continuing north, a
-- branch path and queue line for each of its rides, a boundary fence across the whole map, and a gate. A zone's
-- gate opens once the attraction named in GameConfig.ZoneRequires is repaired and a player pays the zone's cost
-- there; the state is the park folder's `Zone_<key>` attribute (saved by PersistenceService). The fence stays;
-- only the barrier on the road goes away when the zone opens.
local ZoneService = {}

type ZoneReferences = {
	ParkFolder: Folder,
}

type SpendCoins = (Player, number) -> boolean
type GetCoins = (Player) -> number
type Notify = (Player, string, string) -> ()

local FENCE_HALF = 264
local GROUND_MATERIALS: { [string]: Enum.Material } = {
	Sand = Enum.Material.Sand,
	Grass = Enum.Material.Grass,
}
local SIGN_SIZE = Vector3.new(18, 7, 0.6)
local SIGN_CANVAS = Vector2.new(720, 280)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.Position = position
	piece.Color = color
	piece.Material = material
	piece.Anchored = true
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

local function label(parent: Instance, y: number, height: number, size: number, color: Color3): TextLabel
	local text = Instance.new("TextLabel")
	text.Position = UDim2.fromOffset(15, y)
	text.Size = UDim2.new(1, -30, 0, height)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = color
	text.TextSize = size
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.Parent = parent
	return text
end

function ZoneService.Start(
	park: ZoneReferences,
	rideModels: { [string]: Model },
	spendCoins: SpendCoins,
	getCoins: GetCoins,
	notify: Notify
)
	local folder = park.ParkFolder
	local palette = GameConfig.Palette
	local roadX = ParkLayout.ZoneRoadX
	local half = ParkLayout.ZoneRoadHalfWidth
	local pathColor = Color3.fromRGB(150, 140, 122)
	local wood = Color3.fromRGB(150, 98, 62)

	-- Where the road already reaches (the previous zone's far end), so the next zone's road continues from it.
	local roadFrom = ParkLayout.SidePathZ - ParkLayout.SidePathHalfWidth

	for _, key in GameConfig.ZoneOrder do
		local bounds = ParkLayout.ZoneBounds[key]
		local boundaryZ = bounds.BoundaryZ
		local minZ = bounds.MinZ
		local attribute = "Zone_" .. key
		local cost = GameConfig.ZoneCosts[key]
		local zoneName = GameConfig.ZoneNames[key]
		local ground = GameConfig.ZoneGround[key]
		local requiredRide = rideModels[GameConfig.ZoneRequires[key]]
		local requiredName = GameConfig.Rides[GameConfig.ZoneRequires[key]].DisplayName

		local zone = Instance.new("Folder")
		zone.Name = key .. "Zone"
		zone.Parent = folder

		-- Ground beyond the previous edge, the road, and each ride's branch and line.
		part(
			zone,
			"ZoneGround",
			Vector3.new(ParkLayout.GroundHalfWidth * 2, 1, boundaryZ - minZ),
			Vector3.new(0, -0.5, (boundaryZ + minZ) / 2),
			ground.Color,
			GROUND_MATERIALS[ground.Material] or Enum.Material.Grass
		)
		local roadEnd = minZ + 12
		part(
			zone,
			"ZoneRoad",
			Vector3.new(half * 2, 0.2, roadFrom - roadEnd),
			Vector3.new(roadX, 0.1, (roadFrom + roadEnd) / 2),
			pathColor,
			Enum.Material.Cobblestone
		)
		roadFrom = roadEnd
		for rideKey, branchZ in ParkLayout.ZoneBranchZ do
			if GameConfig.Rides[rideKey].Zone == key then
				local site = ParkLayout.Rides[rideKey]
				local lineX = site.QueueHead.X
				local fromX, toX = math.min(lineX, roadX), math.max(lineX, roadX)
				part(
					zone,
					rideKey .. "Branch",
					Vector3.new(toX - fromX + 12, 0.2, 12),
					Vector3.new((fromX + toX) / 2, 0.1, branchZ),
					pathColor,
					Enum.Material.Cobblestone
				)
				-- The line runs from the head away from the ride toward the branch (QueueDirection).
				local tailZ = branchZ + 6
				local headZ = site.QueueHead.Z - 4
				part(
					zone,
					rideKey .. "Line",
					Vector3.new(12, 0.2, math.abs(tailZ - headZ)),
					Vector3.new(lineX, 0.1, (tailZ + headZ) / 2),
					pathColor,
					Enum.Material.Cobblestone
				)
			end
		end

		-- The boundary fence runs across the whole map, with a gap for the road that the barrier fills.
		local function fence(name: string, minX: number, maxX: number)
			local wall = part(
				zone,
				name,
				Vector3.new(maxX - minX, 5, 1),
				Vector3.new((minX + maxX) / 2, 2.5, boundaryZ),
				wood,
				Enum.Material.WoodPlanks
			)
			wall.CastShadow = false
			for x = minX + 4, maxX - 4, 12 do
				part(
					zone,
					name .. "Post",
					Vector3.new(1.6, 6.4, 1.6),
					Vector3.new(x, 3.2, boundaryZ),
					palette.Gold,
					Enum.Material.SmoothPlastic
				)
			end
		end
		fence("FenceWest", -FENCE_HALF, roadX - half)
		fence("FenceEast", roadX + half, FENCE_HALF)

		-- The gate: two tall posts, a barrier across the road, and a signboard above, all one model.
		local gate = Instance.new("Model")
		gate.Name = "ZoneGate_" .. key
		gate.Parent = folder
		for _, side in { -1, 1 } do
			part(
				gate,
				"GatePost",
				Vector3.new(2.4, 12, 2.4),
				Vector3.new(roadX + side * half, 6, boundaryZ),
				palette.Coral,
				Enum.Material.SmoothPlastic
			)
			part(
				gate,
				"GateCap",
				Vector3.new(3.4, 1.2, 3.4),
				Vector3.new(roadX + side * half, 12.4, boundaryZ),
				palette.Gold,
				Enum.Material.SmoothPlastic
			)
		end
		local barrier = part(
			gate,
			"ZoneBarrier",
			Vector3.new(half * 2 - 2.4, 5, 1),
			Vector3.new(roadX, 2.5, boundaryZ),
			Color3.fromRGB(235, 122, 108),
			Enum.Material.WoodPlanks
		)
		barrier.Transparency = 0.15

		local sign = part(
			gate,
			"ZoneSign",
			SIGN_SIZE,
			Vector3.new(roadX, 15.8, boundaryZ),
			palette.Cream,
			Enum.Material.SmoothPlastic
		)
		sign.CanCollide = false
		local frame = part(
			gate,
			"ZoneSignFrame",
			SIGN_SIZE + Vector3.new(0.8, 0.8, -0.2),
			sign.Position,
			palette.Gold,
			Enum.Material.SmoothPlastic
		)
		frame.CanCollide = false
		local statuses: { TextLabel } = {}
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
			gui.CanvasSize = SIGN_CANVAS
			gui.LightInfluence = 0
			gui.Parent = sign
			local title = label(gui, 16, 130, 100, palette.Ink)
			title.Text = zoneName
			table.insert(statuses, label(gui, 150, 110, 64, Color3.fromRGB(206, 78, 64)))
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "OpenZonePrompt"
		prompt.ActionText = "구역 열기"
		prompt.HoldDuration = 1.5
		prompt.MaxActivationDistance = 22
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Enabled = false
		prompt.Parent = barrier

		local function isOpen(): boolean
			return folder:GetAttribute(attribute) == true
		end

		local function refresh()
			local open = isOpen()
			local ready = requiredRide:GetAttribute("IsRepaired") == true
			local text: string
			if open then
				text = "개방!"
			elseif not ready then
				text = string.format("먼저 %s 수리", requiredName)
			else
				text = string.format("%d %s · 게이트에서 E", cost, GameConfig.CurrencyDisplayName)
			end
			for _, status in statuses do
				status.Text = text
			end
			barrier.CanCollide = not open
			barrier.Transparency = if open then 1 else 0.15
			prompt.Enabled = ready and not open
			prompt.ObjectText = string.format("%s · %d %s", zoneName, cost, GameConfig.CurrencyDisplayName)
		end
		folder:GetAttributeChangedSignal(attribute):Connect(refresh)
		requiredRide:GetAttributeChangedSignal("IsRepaired"):Connect(refresh)
		refresh()

		prompt.Triggered:Connect(function(player: Player)
			if isOpen() or requiredRide:GetAttribute("IsRepaired") ~= true then
				return
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root == nil or not root:IsA("BasePart") or (root.Position - barrier.Position).Magnitude > 40 then
				return
			end
			if not spendCoins(player, cost) then
				notify(
					player,
					string.format("%s이 부족해요", GameConfig.CurrencyDisplayName),
					string.format(
						"%s을 열려면 %d %s이 필요해요 (지금 %d)",
						zoneName,
						cost,
						GameConfig.CurrencyDisplayName,
						getCoins(player)
					)
				)
				return
			end
			folder:SetAttribute(attribute, true)
			for _, other in Players:GetPlayers() do
				notify(other, string.format("%s 개방!", zoneName), "새 놀이기구가 기다리고 있어요")
			end
		end)
	end
end

return ZoneService
