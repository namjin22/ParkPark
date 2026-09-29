--!strict

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Once the park is open, guests walk in through the gate, ride an operating attraction, pay a fare
-- to every player in the park, and leave. Guests are server-owned R15 rigs with default avatars.
local GuestService = {}

type GuestReferences = {
	ParkFolder: Folder,
	Carousel: Model,
	CarouselRotor: Model,
	TeacupsRide: Model,
	TeacupsRotor: Model,
}

type RideDefinition = {
	name: string,
	model: Model,
	rotor: Model,
	seatCount: number,
	seatTaken: { [number]: boolean },
	fare: number,
	rideSeconds: number,
	queuePoint: Vector3,
	seatOffset: (number) -> CFrame,
	noticeTitle: string,
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
local function carouselSeatOffset(index: number): CFrame
	local scale = GameConfig.CarouselScale
	local angle = (index - 1) * 2 * math.pi / GameConfig.CarouselSeatCount
	local forward = Vector3.new(math.sin(angle), 0, -math.cos(angle))
	local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * HORSE_ORBIT * scale
		+ forward * SADDLE_FORWARD * scale
		+ Vector3.new(0, (SADDLE_HEIGHT - ROTOR_CENTER_HEIGHT) * scale + RIDER_HIP, 0)
	return CFrame.lookAt(position, position + forward)
end

local function teacupsSeatOffset(index: number): CFrame
	local scale = GameConfig.TeacupsScale
	local angle = (index - 1) * 2 * math.pi / GameConfig.TeacupsSeatCount
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local position = outward * GameConfig.TeacupsSeatRadius * scale
		+ Vector3.new(
			0,
			(GameConfig.TeacupsSeatHeight - GameConfig.TeacupsRotorCenterHeight) * scale + GameConfig.TeacupsRiderHip,
			0
		)
	return CFrame.lookAt(position, position + outward)
end

function GuestService.Start(park: GuestReferences, awardCoins: AwardCoins, notify: Notify)
	ensureCollisionGroup()

	local guestFolderInstance = park.ParkFolder:FindFirstChild("Guests")
	if guestFolderInstance == nil then
		local folder = Instance.new("Folder")
		folder.Name = "Guests"
		folder.Parent = park.ParkFolder
		guestFolderInstance = folder
	elseif not guestFolderInstance:IsA("Folder") then
		error("[ParkPark] ParkParkWorld.Guests must be a Folder")
	end
	local guestFolder = guestFolderInstance :: Folder

	local guestCount = 0
	local carouselPivot = park.Carousel:GetPivot()
	local platformFrontZ = carouselPivot.Position.Z + 12 * GameConfig.CarouselScale
	local teacupsPivot = park.TeacupsRide:GetPivot().Position
	local rides: { RideDefinition } = {
		{
			name = "Carousel",
			model = park.Carousel,
			rotor = park.CarouselRotor,
			seatCount = GameConfig.CarouselSeatCount,
			seatTaken = {},
			fare = GameConfig.GuestRideFare,
			rideSeconds = GameConfig.GuestRideSeconds,
			queuePoint = Vector3.new(carouselPivot.Position.X, 0, platformFrontZ + 3),
			seatOffset = carouselSeatOffset,
			noticeTitle = "손님이 회전목마를 탔어요",
		},
		{
			name = "Teacups",
			model = park.TeacupsRide,
			rotor = park.TeacupsRotor,
			seatCount = GameConfig.TeacupsSeatCount,
			seatTaken = {},
			fare = GameConfig.TeacupsGuestRideFare,
			rideSeconds = GameConfig.GuestRideSeconds,
			queuePoint = Vector3.new(teacupsPivot.X, 0, teacupsPivot.Z + GameConfig.TeacupsPlatformRadius + 2.5),
			seatOffset = teacupsSeatOffset,
			noticeTitle = "손님이 찻잔을 탔어요",
		},
	}

	local function findAvailableRide(): (RideDefinition?, number?)
		local candidates: { { Ride: RideDefinition, Seat: number } } = {}
		for _, ride in rides do
			if ride.model:GetAttribute("IsOperating") == true and ride.rotor.PrimaryPart ~= nil then
				for seat = 1, ride.seatCount do
					if not ride.seatTaken[seat] then
						table.insert(candidates, { Ride = ride, Seat = seat })
						break
					end
				end
			end
		end
		if #candidates == 0 then
			return nil, nil
		end

		local selected = candidates[math.random(1, #candidates)]
		selected.Ride.seatTaken[selected.Seat] = true
		return selected.Ride, selected.Seat
	end

	local function payFare(ride: RideDefinition)
		for _, player in Players:GetPlayers() do
			if awardCoins(player, ride.fare) then
				notify(player, ride.noticeTitle, string.format("+%d %s", ride.fare, GameConfig.CurrencyDisplayName))
			end
		end
	end

	local function runGuest(guest: Model)
		local humanoid = guest:FindFirstChildOfClass("Humanoid")
		local root = guest:FindFirstChild("HumanoidRootPart")
		if humanoid == nil or root == nil or not root:IsA("BasePart") then
			return
		end

		local lane = math.random(-30, 30) / 10
		walkTo(humanoid, Vector3.new(lane, 0, GATE_Z))
		walkTo(humanoid, Vector3.new(lane * 2, 0, platformFrontZ + 3 + math.random(0, 20) / 10))

		local ride: RideDefinition? = nil
		local seat: number? = nil
		local waited = 0
		while ride == nil and waited < QUEUE_TIMEOUT and guest.Parent ~= nil do
			ride, seat = findAvailableRide()
			if ride == nil then
				waited += task.wait(0.5)
			end
		end

		if ride and seat and guest:IsDescendantOf(guestFolder) then
			local queuePoint = ride.queuePoint
			if ride.name == "Carousel" then
				queuePoint += Vector3.new(lane * 2 + math.random(-8, 8) / 10, 0, math.random(0, 20) / 10)
			else
				queuePoint += Vector3.new(math.random(-20, 20) / 10, 0, math.random(-8, 8) / 10)
			end
			walkTo(humanoid, queuePoint)

			local rotorRoot = ride.rotor.PrimaryPart
			if rotorRoot then
				-- The rotor root is anchored, so the weld alone carries the rider around.
				humanoid.Sit = true
				root.CFrame = rotorRoot.CFrame * ride.seatOffset(seat)
				local weld = Instance.new("WeldConstraint")
				weld.Name = "RideWeld"
				weld.Part0 = rotorRoot
				weld.Part1 = root
				weld.Parent = root

				task.wait(ride.rideSeconds)
				if weld.Parent ~= nil then
					weld:Destroy()
				end
				ride.seatTaken[seat] = nil
				if guest:IsDescendantOf(guestFolder) and humanoid.Health > 0 then
					humanoid.Sit = false
					root.CFrame = CFrame.new(queuePoint + Vector3.new(0, 3, 0))
					humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
					payFare(ride)
				end
			else
				ride.seatTaken[seat] = nil
			end
		elseif ride and seat then
			ride.seatTaken[seat] = nil
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
