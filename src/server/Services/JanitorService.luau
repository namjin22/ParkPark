--!strict

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- A cleaning cart beside the entrance path sells janitors. Each hired janitor is a small R15 character in a
-- green outfit who walks to the nearest unclaimed piece of litter, sweeps it away after a moment, and
-- repeats; when nothing is left, they wait near the cart. Each piece a janitor clears pays its coin reward to
-- every player, just as if they had picked it up themselves.
local JanitorService = {}

type AwardCoins = (Player, number) -> boolean
type SpendCoins = (Player, number) -> boolean
type GetCoins = (Player) -> number
type Notify = (Player, string, string) -> ()
type Popup = (Vector3, string) -> ()

type JanitorReferences = {
	ParkFolder: Folder,
}

local GUEST_COLLISION_GROUP = "ParkParkGuests"
local ARRIVAL_DISTANCE = 4
local CART_POSITION = ParkLayout.JanitorCartPosition

local function buildCart(parkFolder: Folder): (BasePart, ProximityPrompt)
	local existing = parkFolder:FindFirstChild("JanitorCart")
	if existing and existing:IsA("Model") then
		local body = existing:FindFirstChild("CartBody") :: BasePart
		return body, body:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	end

	local model = Instance.new("Model")
	model.Name = "JanitorCart"

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

	-- A little cart with a broom and a bucket: a placeholder prop, not final art.
	local body = part(
		"CartBody",
		Vector3.new(6, 3, 4),
		CART_POSITION + Vector3.new(0, 2.6, 0),
		GameConfig.Palette.Mint,
		Enum.Material.SmoothPlastic
	)
	part(
		"CartStripe",
		Vector3.new(6.2, 0.8, 4.2),
		CART_POSITION + Vector3.new(0, 3.9, 0),
		GameConfig.Palette.Cream,
		Enum.Material.SmoothPlastic
	)
	part(
		"CartBucket",
		Vector3.new(1.8, 2, 1.8),
		CART_POSITION + Vector3.new(2, 5.4, 0.5),
		GameConfig.Palette.Gold,
		Enum.Material.SmoothPlastic
	)
	local broom = part(
		"CartBroom",
		Vector3.new(0.4, 7, 0.4),
		CART_POSITION + Vector3.new(-2.4, 5.5, -1),
		Color3.fromRGB(122, 84, 52),
		Enum.Material.Wood
	)
	broom.CFrame = CFrame.new(CART_POSITION + Vector3.new(-2.4, 5.5, -1)) * CFrame.Angles(0, 0, math.rad(12))
	for _, x in { -1.8, 1.8 } do
		local wheel = part(
			"CartWheel",
			Vector3.new(1, 1.6, 1.6),
			CART_POSITION + Vector3.new(x, 0.8, 2.2),
			GameConfig.Palette.Ink,
			Enum.Material.SmoothPlastic
		)
		wheel.Shape = Enum.PartType.Cylinder
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HirePrompt"
	prompt.ActionText = "청소원 고용"
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = body

	model.PrimaryPart = body
	model.Parent = parkFolder
	return body, prompt
end

local function createJanitorModel(): Model?
	local description = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(234, 184, 146)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = GameConfig.Palette.Mint
	description.LeftLegColor = GameConfig.Palette.Ink
	description.RightLegColor = GameConfig.Palette.Ink

	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or result == nil then
		warn("[ParkPark] Could not create a janitor: " .. tostring(result))
		return nil
	end

	local janitor = result :: Model
	janitor.Name = "Janitor"
	local humanoid = janitor:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.WalkSpeed = GameConfig.JanitorWalkSpeed
	end
	pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered(GUEST_COLLISION_GROUP) then
			PhysicsService:RegisterCollisionGroup(GUEST_COLLISION_GROUP)
		end
	end)
	for _, descendant in janitor:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = GUEST_COLLISION_GROUP
		end
	end
	return janitor
end

local function flatDistance(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

function JanitorService.Start(
	park: JanitorReferences,
	awardCoins: AwardCoins,
	spendCoins: SpendCoins,
	getCoins: GetCoins,
	notify: Notify,
	popup: Popup,
	litter: {
		Nearest: (Vector3) -> Model?,
		Remove: (Model) -> boolean,
	},
	initialHired: number?
)
	local cart, prompt = buildCart(park.ParkFolder)
	local currency = GameConfig.CurrencyDisplayName
	local folder = Instance.new("Folder")
	folder.Name = "Janitors"
	folder.Parent = park.ParkFolder
	local hired = 0

	local function refreshPrompt()
		local cost = GameConfig.JanitorCosts[hired + 1]
		prompt.Enabled = cost ~= nil
		if cost then
			prompt.ObjectText = string.format(
				"청소원 %d/%d · %d %s · 치울 때마다 +%d",
				hired + 1,
				#GameConfig.JanitorCosts,
				cost,
				currency,
				GameConfig.LitterReward
			)
		end
		park.ParkFolder:SetAttribute("Janitors", hired)
	end
	refreshPrompt()

	-- Walks to a spot, re-issuing MoveTo (one call gives up after a few seconds); teleports next to it if stuck.
	local function walkTo(model: Model, humanoid: Humanoid, root: BasePart, point: Vector3)
		local elapsed = 0
		local stuckFor = 0
		local last = root.Position
		while model.Parent ~= nil and flatDistance(root.Position, point) > ARRIVAL_DISTANCE do
			humanoid:MoveTo(point)
			elapsed += task.wait(0.3)
			if (root.Position - last).Magnitude < 0.6 then
				stuckFor += 0.3
			else
				stuckFor = 0
			end
			last = root.Position
			if stuckFor > 2.5 or elapsed > 40 then
				model:PivotTo(CFrame.new(point + Vector3.new(3, 3, 0)))
				return
			end
		end
	end

	local function runJanitor(model: Model)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if humanoid == nil or root == nil or not root:IsA("BasePart") then
			return
		end

		while model.Parent ~= nil and park.ParkFolder.Parent ~= nil do
			local target = litter.Nearest(root.Position)
			if target == nil then
				-- Nothing to clean: wait by the cart.
				local home = CART_POSITION + Vector3.new(6, 0, 4)
				if flatDistance(root.Position, home) > 8 then
					walkTo(model, humanoid, root, home)
				end
				task.wait(1.5)
			else
				target:SetAttribute("Claimed", true)
				local spot = target:GetPivot().Position
				walkTo(model, humanoid, root, spot)
				if target.Parent ~= nil then
					-- A moment of sweeping, then the litter is gone.
					task.wait(GameConfig.JanitorCleanSeconds)
					if litter.Remove(target) then
						for _, other in Players:GetPlayers() do
							awardCoins(other, GameConfig.LitterReward)
						end
						popup(spot + Vector3.new(0, 5, 0), string.format("+%d %s", GameConfig.LitterReward, currency))
					end
				end
			end
		end
	end

	-- Creates a janitor, counts them as hired, and sets them cleaning. False if the character could not be made.
	local function spawnJanitor(): boolean
		local model = createJanitorModel()
		if model == nil then
			return false
		end
		hired += 1
		model:PivotTo(CFrame.new(CART_POSITION + Vector3.new(6, 4, 4)))
		model.Parent = folder
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root:SetNetworkOwner(nil)
		end
		task.spawn(function()
			local ok, err = pcall(function()
				runJanitor(model)
			end)
			if not ok then
				warn("[ParkPark] Janitor stopped: " .. tostring(err))
			end
		end)
		return true
	end

	-- Janitors hired in a saved park come back at the cart.
	for _ = 1, math.min(initialHired or 0, #GameConfig.JanitorCosts) do
		spawnJanitor()
	end
	refreshPrompt()

	prompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
		if playerRoot == nil or not playerRoot:IsA("BasePart") then
			return
		end
		if (playerRoot.Position - cart.Position).Magnitude > prompt.MaxActivationDistance + 6 then
			return
		end
		local cost = GameConfig.JanitorCosts[hired + 1]
		if cost == nil then
			return
		end
		if not spendCoins(player, cost) then
			notify(
				player,
				string.format("%s이 부족해요", currency),
				string.format("청소원 고용에 %d %s이 필요해요 (지금 %d)", cost, currency, getCoins(player))
			)
			return
		end

		if not spawnJanitor() then
			return
		end
		refreshPrompt()
		notify(
			player,
			"청소원을 고용했어요",
			string.format(
				"-%d %s · 치운 쓰레기마다 코인을 받아요 (%d/%d)",
				cost,
				currency,
				hired,
				#GameConfig.JanitorCosts
			)
		)
	end)
end

return JanitorService
