--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Once the entrance is cleaned, litter keeps appearing near the paths. Picking a piece up pays a few
-- coins, so there is always a small job for a player while guests fill the rides.
local LitterService = {}

type LitterReferences = {
	ParkFolder: Folder,
}

type AwardCoins = (Player, number) -> boolean
type Popup = (Vector3, string) -> ()
type FindTemplate = () -> Model?

-- What the janitors use: the nearest piece nobody else has claimed, and a way to clear one away.
export type LitterControl = {
	Nearest: (Vector3) -> Model?,
	Remove: (Model) -> boolean,
}

local MIN_SPACING = 9
local PICKUP_DISTANCE = 18

local function isNearRide(x: number, z: number): boolean
	for _, spot in { ParkLayout.GeneratorPosition, ParkLayout.JanitorCartPosition } do
		if math.abs(x - spot.X) < 14 and math.abs(z - spot.Z) < 14 then
			return true
		end
	end
	for _, site in ParkLayout.Rides do
		local dx, dz = x - site.Pivot.X, z - site.Pivot.Z
		if math.sqrt(dx * dx + dz * dz) < site.PlatformRadius + 6 then
			return true
		end
	end
	return false
end

local function randomPoint(existing: { Vector3 }): Vector3?
	for _ = 1, 25 do
		local x: number
		local z: number
		if math.random() < 0.5 then
			-- Along the main path: on its edges and the grass beside it.
			x = (if math.random() < 0.5 then -1 else 1) * (6 + math.random() * 22)
			z = -45 + math.random() * 130
		else
			x = -150 + math.random() * 300
			z = ParkLayout.SidePathZ + (if math.random() < 0.5 then -1 else 1) * (5 + math.random() * 20)
		end

		local nearGate = math.abs(z - ParkLayout.GateZ) < 10 and math.abs(x) < 32
		local nearSpawn = math.abs(z - ParkLayout.SpawnZ) < 8 and math.abs(x) < 12
		if not nearGate and not nearSpawn and not isNearRide(x, z) then
			local point = Vector3.new(x, 0, z)
			local clear = true
			for _, other in existing do
				if (other - point).Magnitude < MIN_SPACING then
					clear = false
					break
				end
			end
			if clear then
				return point
			end
		end
	end
	return nil
end

-- Graybox stand-in used until ParkParkLitter.obj is imported.
local function buildGrayboxLitter(): Model
	local model = Instance.new("Model")
	model.Name = "Litter"
	local function part(name: string, size: Vector3, offset: Vector3, color: Color3, shape: Enum.PartType?)
		local piece = Instance.new("Part")
		piece.Name = name
		piece.Size = size
		piece.Color = color
		piece.Material = Enum.Material.SmoothPlastic
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanQuery = false
		if shape then
			piece.Shape = shape
		end
		piece.CFrame = CFrame.new(offset)
		piece.Parent = model
		return piece
	end
	local tub = part("LitterPiece", Vector3.new(1.8, 2, 1.8), Vector3.new(0, 1, 0), Color3.fromRGB(232, 92, 82), nil)
	part(
		"Cup",
		Vector3.new(1.4, 1.2, 1.2),
		Vector3.new(2.2, 0.6, 0.8),
		Color3.fromRGB(245, 217, 171),
		Enum.PartType.Cylinder
	)
	part("Wrapper", Vector3.new(1.8, 0.2, 1.4), Vector3.new(-1.8, 0.1, 1.1), Color3.fromRGB(135, 79, 74), nil)
	model.PrimaryPart = tub
	return model
end

function LitterService.Start(
	park: LitterReferences,
	awardCoins: AwardCoins,
	popup: Popup,
	findTemplate: FindTemplate
): LitterControl
	local folder = park.ParkFolder:FindFirstChild("Litter")
	if folder == nil then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "Litter"
		newFolder.Parent = park.ParkFolder
		folder = newFolder
	end
	local litterFolder = folder :: Instance

	local pieces: { Model } = {}
	local currency = GameConfig.CurrencyDisplayName

	local function positions(): { Vector3 }
		local result: { Vector3 } = {}
		for _, piece in pieces do
			table.insert(result, piece:GetPivot().Position)
		end
		return result
	end

	local function spawnPiece()
		local point = randomPoint(positions())
		if point == nil then
			return
		end

		local template = findTemplate()
		local piece = if template then template:Clone() else buildGrayboxLitter()
		piece.Name = "Litter"
		piece:PivotTo(CFrame.new(point) * CFrame.Angles(0, math.random() * math.pi * 2, 0))

		local target = piece:FindFirstChild("LitterPiece", true)
		if target == nil or not target:IsA("BasePart") then
			piece:Destroy()
			return
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PickupPrompt"
		prompt.ActionText = "쓰레기 줍기"
		prompt.ObjectText = string.format("+%d %s", GameConfig.LitterReward, currency)
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = target

		local taken = false
		prompt.Triggered:Connect(function(player: Player)
			if taken then
				return
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if
				root == nil
				or not root:IsA("BasePart")
				or (root.Position - target.Position).Magnitude > PICKUP_DISTANCE
			then
				return
			end
			if not awardCoins(player, GameConfig.LitterReward) then
				return
			end

			taken = true
			popup(target.Position + Vector3.new(0, 4, 0), string.format("+%d %s", GameConfig.LitterReward, currency))
			local index = table.find(pieces, piece)
			if index then
				table.remove(pieces, index)
			end
			piece:Destroy()
		end)

		piece.Parent = litterFolder
		table.insert(pieces, piece)
	end

	task.spawn(function()
		-- Litter only starts once the entrance is clean, so the first job is always the debris pile.
		while park.ParkFolder.Parent ~= nil and park.ParkFolder:GetAttribute("EntranceCleared") ~= true do
			task.wait(1)
		end
		for _ = 1, 3 do
			spawnPiece()
		end
		while park.ParkFolder.Parent ~= nil do
			task.wait(GameConfig.LitterSpawnSeconds)
			if #pieces < GameConfig.LitterMax then
				spawnPiece()
			end
		end
	end)

	return {
		Nearest = function(from: Vector3): Model?
			local best: Model? = nil
			local bestDistance = math.huge
			for _, piece in pieces do
				if piece:GetAttribute("Claimed") ~= true then
					local distance = (piece:GetPivot().Position - from).Magnitude
					if distance < bestDistance then
						best, bestDistance = piece, distance
					end
				end
			end
			return best
		end,
		Remove = function(piece: Model): boolean
			local index = table.find(pieces, piece)
			if index == nil then
				return false
			end
			table.remove(pieces, index)
			piece:Destroy()
			return true
		end,
	}
end

return LitterService
