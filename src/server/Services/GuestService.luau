--!strict

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Once the park is open, guests walk in through the gate, ride the carousel, pay a fare to
-- every player in the park, and leave. Guests are server-owned R15 rigs with default avatars.
local GuestService = {}

type GuestReferences = {
	ParkFolder: Folder,
	Carousel: Model,
	CarouselRotor: Model,
}

type AwardCoins = (Player, number) -> boolean
type Notify = (Player, string, string) -> ()

local GUEST_COLLISION_GROUP = "ParkParkGuests"
local ENTRY_Z = 44
local GATE_Z = 24
local WALK_TIMEOUT = 12
local QUEUE_TIMEOUT = 40

-- Horse geometry in unscaled OBJ units (tools/generate_parkpark_meshes.py make_rotor/add_horse).
local HORSE_ORBIT = 6.6
local SADDLE_HEIGHT = 2.89
local SADDLE_FORWARD = 0.18
local ROTOR_CENTER_HEIGHT = 6.35
-- Seated R15 root sits roughly this far above the saddle surface.
local RIDER_HIP = 1.25

local SKIN_TONES = {
	Color3.fromRGB(255, 220, 190),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(198, 140, 104),
	Color3.fromRGB(141, 92, 64),
}
local OUTFIT_COLORS = {
	Color3.fromRGB(232, 92, 82),
	Color3.fromRGB(84, 166, 135),
	Color3.fromRGB(235, 171, 69),
	Color3.fromRGB(110, 140, 200),
	Color3.fromRGB(245, 217, 171),
}

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

local function ensureCollisionGroup()
	local ok = pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered(GUEST_COLLISION_GROUP) then
			PhysicsService:RegisterCollisionGroup(GUEST_COLLISION_GROUP)
		end
		PhysicsService:CollisionGroupSetCollidable(GUEST_COLLISION_GROUP, GUEST_COLLISION_GROUP, false)
	end)
	if not ok then
		warn("[ParkPark] Could not set up the guest collision group")
	end
end

local function createGuest(): Model?
	local description = Instance.new("HumanoidDescription")
	local skin = pick(SKIN_TONES)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = pick(OUTFIT_COLORS)
	local legs = pick(OUTFIT_COLORS)
	description.LeftLegColor = legs
	description.RightLegColor = legs

	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or result == nil then
		warn("[ParkPark] Could not create a guest: " .. tostring(result))
		return nil
	end

	local guest = result :: Model
	guest.Name = "Guest"
	local humanoid = guest:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.WalkSpeed = 10
	end
	for _, descendant in guest:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = GUEST_COLLISION_GROUP
		end
	end
	return guest
end

local function walkTo(humanoid: Humanoid, point: Vector3): boolean
	local reached = false
	local connection = humanoid.MoveToFinished:Connect(function(success: boolean)
		reached = success
	end)
	humanoid:MoveTo(point)
	local elapsed = 0
	while not reached and elapsed < WALK_TIMEOUT and humanoid.Parent ~= nil do
		elapsed += task.wait(0.25)
	end
	connection:Disconnect()
	return reached
end

-- Seat transform relative to the rotor root (CenterPost), facing the direction of travel.
local function seatOffset(index: number): CFrame
	local scale = GameConfig.CarouselScale
	local angle = (index - 1) * 2 * math.pi / GameConfig.CarouselSeatCount
	local forward = Vector3.new(math.sin(angle), 0, -math.cos(angle))
	local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * HORSE_ORBIT * scale
		+ forward * SADDLE_FORWARD * scale
		+ Vector3.new(0, (SADDLE_HEIGHT - ROTOR_CENTER_HEIGHT) * scale + RIDER_HIP, 0)
	return CFrame.lookAt(position, position + forward)
end

function GuestService.Start(park: GuestReferences, awardCoins: AwardCoins, notify: Notify)
	ensureCollisionGroup()

	local guestFolder = park.ParkFolder:FindFirstChild("Guests")
	if guestFolder == nil then
		local folder = Instance.new("Folder")
		folder.Name = "Guests"
		folder.Parent = park.ParkFolder
		guestFolder = folder
	end

	local seatTaken: { [number]: boolean } = {}
	local guestCount = 0
	local carouselPivot = park.Carousel:GetPivot()
	local platformFrontZ = carouselPivot.Position.Z + 12 * GameConfig.CarouselScale

	local function takeSeat(): number?
		for index = 1, GameConfig.CarouselSeatCount do
			if not seatTaken[index] then
				seatTaken[index] = true
				return index
			end
		end
		return nil
	end

	local function payFare()
		for _, player in Players:GetPlayers() do
			if awardCoins(player, GameConfig.GuestRideFare) then
				notify(
					player,
					"손님이 회전목마를 탔어요",
					string.format("+%d %s", GameConfig.GuestRideFare, GameConfig.CurrencyDisplayName)
				)
			end
		end
	end

	local function runGuest(guest: Model)
		local humanoid = guest:FindFirstChildOfClass("Humanoid")
		local root = guest:FindFirstChild("HumanoidRootPart")
		local rotorRoot = park.CarouselRotor.PrimaryPart
		if humanoid == nil or root == nil or not root:IsA("BasePart") or rotorRoot == nil then
			return
		end

		local lane = math.random(-30, 30) / 10
		walkTo(humanoid, Vector3.new(lane, 0, GATE_Z))
		local queuePoint = Vector3.new(lane * 2, 0, platformFrontZ + 3 + math.random(0, 20) / 10)
		walkTo(humanoid, queuePoint)

		local seat: number? = nil
		local waited = 0
		while seat == nil and waited < QUEUE_TIMEOUT and guest.Parent ~= nil do
			if park.Carousel:GetAttribute("IsOperating") == true then
				seat = takeSeat()
			end
			if seat == nil then
				waited += task.wait(0.5)
			end
		end

		if seat and guest.Parent ~= nil then
			-- The rotor root is anchored, so the weld alone carries the rider around.
			humanoid.Sit = true
			root.CFrame = rotorRoot.CFrame * seatOffset(seat)
			local weld = Instance.new("WeldConstraint")
			weld.Name = "RideWeld"
			weld.Part0 = rotorRoot
			weld.Part1 = root
			weld.Parent = root

			task.wait(GameConfig.GuestRideSeconds)
			weld:Destroy()
			seatTaken[seat] = nil
			humanoid.Sit = false
			root.CFrame = CFrame.new(queuePoint + Vector3.new(0, 3, 0))
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			payFare()
		end

		walkTo(humanoid, Vector3.new(if lane < 0 then -18 else 18, 0, ENTRY_Z))
	end

	local function spawnGuest()
		local guest = createGuest()
		if guest == nil then
			return
		end

		guestCount += 1
		guest:PivotTo(CFrame.lookAt(Vector3.new(math.random(-40, 40) / 10, 3, ENTRY_Z), Vector3.new(0, 3, GATE_Z)))
		guest.Parent = guestFolder
		local root = guest:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root:SetNetworkOwner(nil)
		end

		task.spawn(function()
			local ok, err = pcall(function()
				runGuest(guest)
			end)
			if not ok then
				warn("[ParkPark] Guest stopped: " .. tostring(err))
			end
			guest:Destroy()
			guestCount -= 1
		end)
	end

	task.spawn(function()
		while park.ParkFolder.Parent ~= nil do
			if park.ParkFolder:GetAttribute("ParkOpen") == true and guestCount < GameConfig.MaxGuests then
				spawnGuest()
			end
			task.wait(GameConfig.GuestSpawnSeconds)
		end
	end)
end

return GuestService
