--!strict

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local ParkBuilder = require(script.Parent:WaitForChild("ParkBuilder"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))
local ExtraRideService = require(script.Parent:WaitForChild("ExtraRideService"))
local ExtraRides = require(Config:WaitForChild("ExtraRides"))

-- Once the park is open, guests walk in along the paths, pick a ride at random, and stand in that ride's
-- line. The guest at the head of a line shows a prompt: a player walks up and lets them on, or the ride's
-- staff (an upgrade) does it automatically. A guest who boards pays the fare to every player, rides, then
-- may join another random ride or leave the way they came.
local GuestService = {}

type ExtraRide = ParkBuilder.ExtraRide

type GuestReferences = {
	Extras: { [string]: ExtraRide },
	ParkFolder: Folder,
	Carousel: Model,
	CarouselRotor: Model,
	TeacupsRide: Model,
	TeacupsRotor: Model,
	TeacupCups: Model?,
	BumperRide: Model,
	BumperCars: Model,
	SnackStand: Model,
	SnackCounter: BasePart,
	FerrisRide: Model,
	FerrisCabins: Model,
	SwingRide: Model,
	SwingSeats: Model,
	PirateRide: Model,
	PirateShip: BasePart,
	HauntedHouse: Model,
	HauntedBody: BasePart,
	CoasterRide: Model,
	CoasterCars: Model,
	FlumeRide: Model,
	FlumeCars: Model,
	DropRide: Model,
	DropGondola: BasePart,
	GiftShop: Model,
	GiftCounter: BasePart,
	TrainRide: Model,
	TrainCars: Model,
}

type Guest = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	prompt: ProximityPrompt,
	lane: number,
	jitter: number,
	ridesTaken: number,
	ride: Ride?,
	slot: Vector3,
	arrived: boolean,
	seat: number?,
	alive: boolean,
}

type Ride = {
	key: string,
	displayName: string,
	model: Model,
	seatPart: (number) -> BasePart?,
	seatOffset: (number) -> CFrame,
	seatCount: number,
	-- A shop serves guests where they stand instead of seating them on the ride.
	service: boolean,
	-- Optional extra condition for a seat, e.g. the Ferris wheel only lets guests on at the bottom.
	canBoard: ((number) -> boolean)?,
	-- Guests go inside a building for the ride and are out of sight until it ends (the haunted house).
	hidden: boolean?,
	seatTaken: { [number]: boolean },
	queue: { Guest },
	lastStaffBoarding: number,
}

type AwardCoins = (Player, number) -> boolean
type Notify = (Player, string, string) -> ()
type Popup = (Vector3, string) -> ()

local GUEST_COLLISION_GROUP = "ParkParkGuests"
-- Guests inside the haunted house wait here, far below the park, standing still.
local HIDDEN_ORIGIN = Vector3.new(0, -400, 0)
local ARRIVAL_DISTANCE = 4.5
local QUEUE_TICK = 0.4

-- Horse geometry in unscaled OBJ units (tools/generate_parkpark_meshes.py make_rotor/add_horse).
local HORSE_ORBIT = 6.6
local SADDLE_HEIGHT = 2.89
-- Riders sit behind the pole, toward the horse's tail.
local SADDLE_FORWARD = -0.45
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

local function createGuestModel(): Model?
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
		humanoid.WalkSpeed = GameConfig.GuestWalkSpeed
	end
	for _, descendant in guest:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = GUEST_COLLISION_GROUP
		end
	end
	return guest
end

local function flatDistance(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

-- Walks to a point on the path, re-issuing MoveTo because a single call gives up after a few seconds.
local function walkTo(guest: Guest, point: Vector3)
	local timeout = math.max(6, flatDistance(guest.root.Position, point) / GameConfig.GuestWalkSpeed * 2.5)
	local elapsed = 0
	while guest.alive and elapsed < timeout and flatDistance(guest.root.Position, point) > ARRIVAL_DISTANCE do
		guest.humanoid:MoveTo(point)
		elapsed += task.wait(0.3)
	end
end

local function followRoute(guest: Guest, route: { Vector3 })
	for _, point in route do
		if not guest.alive then
			return
		end
		walkTo(guest, point)
	end
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

-- Legacy single-mesh teacup rotor: the seat sits inside the cup on the rotor.
local function legacyTeacupsSeatOffset(index: number): CFrame
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

-- A guest stands waist-deep in a spinning cup; the offset is relative to the cup part's centre.
local function cupSeatOffset(_: number): CFrame
	local scale = GameConfig.TeacupsScale
	return CFrame.new(
		0,
		(GameConfig.TeacupCupFloorHeight - GameConfig.TeacupCupCenterHeight) * scale + GameConfig.TeacupStandHeight,
		0
	)
end

-- A Ferris cabin is a bench under a roof; the offset is relative to the cabin part's centre.
local function ferrisSeatOffset(_: number): CFrame
	local scale = GameConfig.FerrisScale
	return CFrame.new(
		0,
		(GameConfig.FerrisSeatHeight - GameConfig.FerrisCabinCenterHeight) * scale + GameConfig.FerrisRiderHip,
		0
	)
end

-- A swing seat is a chair on chains; the guest sits on the bench facing the direction of travel. Set
-- GameConfig.SwingSeatFlip when the imported mesh's front ends up on the opposite side of the seat part.
local function swingSeatOffset(_: number): CFrame
	local scale = GameConfig.SwingScale
	local x = -GameConfig.SwingSeatCenterX * scale
	local y = (GameConfig.SwingSeatTop - GameConfig.SwingSeatCenterY) * scale + GameConfig.SwingRiderHip
	local z = (0 - GameConfig.SwingSeatCenterZ) * scale
	if GameConfig.SwingSeatFlip then
		return CFrame.new(-x, y, -z) * CFrame.Angles(0, math.pi, 0)
	end
	return CFrame.new(x, y, z)
end

-- Pirate ship benches run across the deck: the four rows sit back to back around the mast, two guests on each,
-- the front rows facing one end and the back rows the other. The offset is relative to the ship part's centre.
local function pirateSeatOffset(seat: number): CFrame
	local scale = GameConfig.PirateScale
	local row = (seat - 1) // 2 + 1
	local column = if (seat - 1) % 2 == 0 then -1 else 1
	local benchZ = GameConfig.PirateBenchZ[row]
	local position = Vector3.new(
		column * GameConfig.PirateSeatColumnX * scale,
		(GameConfig.PirateSeatTop - GameConfig.PirateShipCenterY) * scale + GameConfig.PirateRiderHip,
		benchZ * scale
	)
	return if benchZ > 0 then CFrame.new(position) * CFrame.Angles(0, math.pi, 0) else CFrame.new(position)
end

-- Track-ride cars (coaster, flume) carry two rows of two; every seat faces the direction of travel (the car's
-- -Z). The offset is relative to the car part's centre, from the ride's `<Prefix>...` numbers in GameConfig.
local TRACK_RIDES: { [string]: boolean } = { Coaster = true, Flume = true, Drop = true, Train = true }

local function trackSeatOffset(prefix: string): (number) -> CFrame
	local settings = GameConfig :: any
	return function(seat: number): CFrame
		local scale = settings[prefix .. "Scale"]
		local index = (seat - 1) % 4
		local row = if index < 2 then -1 else 1
		local column = if index % 2 == 0 then -1 else 1
		return CFrame.new(
			column * settings[prefix .. "ColumnX"] * scale,
			(settings[prefix .. "SeatTop"] - settings[prefix .. "CarCenterY"]) * scale + settings[prefix .. "RiderHip"],
			row * settings[prefix .. "RowZ"] * scale
		)
	end
end

-- The drop tower's gondola seats eight guests in a ring, all facing outward; the offset is relative to the
-- gondola part's centre.
local function dropSeatOffset(seat: number): CFrame
	local scale = GameConfig.DropScale
	local angle = (seat - 1) * 2 * math.pi / GameConfig.DropSeatCount
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local position = outward * GameConfig.DropSeatRadius * scale
		+ Vector3.new(0, (GameConfig.DropSeatTop - GameConfig.DropGondolaCenterY) * scale + GameConfig.DropRiderHip, 0)
	return CFrame.lookAt(position, position + outward)
end

-- Bumper cars face local -Z, so a rider with an identity rotation looks along the car's travel.
local function bumperSeatOffset(_: number): CFrame
	local scale = GameConfig.BumperCarScale
	return CFrame.new(
		0,
		(GameConfig.BumperSeatHeight - GameConfig.BumperCarCenterHeight) * scale + GameConfig.BumperRiderHip,
		GameConfig.BumperSeatZ * scale
	)
end

function GuestService.Start(park: GuestReferences, awardCoins: AwardCoins, notify: Notify, popup: Popup)
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

	local currency = GameConfig.CurrencyDisplayName
	local guestCount = 0

	local function newRide(
		key: string,
		model: Model,
		seatPart: (number) -> BasePart?,
		seatOffset: (number) -> CFrame,
		seatCount: number,
		service: boolean
	): Ride
		return {
			key = key,
			displayName = GameConfig.Rides[key].DisplayName,
			model = model,
			seatPart = seatPart,
			seatOffset = seatOffset,
			seatCount = seatCount,
			service = service,
			seatTaken = {},
			queue = {},
			lastStaffBoarding = os.clock(),
		}
	end

	local cups = park.TeacupCups
	local rides: { Ride } = {
		newRide("Carousel", park.Carousel, function()
			return park.CarouselRotor.PrimaryPart
		end, carouselSeatOffset, GameConfig.CarouselSeatCount, false),
		if cups
			then newRide("Teacups", park.TeacupsRide, function(seat: number)
				local cup = cups:FindFirstChild(string.format("TeacupCup%d", seat))
				return if cup and cup:IsA("BasePart") then cup else nil
			end, cupSeatOffset, GameConfig.TeacupCupCount, false)
			else newRide("Teacups", park.TeacupsRide, function()
				return park.TeacupsRotor.PrimaryPart
			end, legacyTeacupsSeatOffset, GameConfig.TeacupsSeatCount, false),
		newRide("Bumper", park.BumperRide, function(seat: number)
			local car = park.BumperCars:FindFirstChild(string.format("BumperCar%d", seat))
			return if car and car:IsA("BasePart") then car else nil
		end, bumperSeatOffset, GameConfig.BumperSeatCount, false),
		newRide("Snack", park.SnackStand, function()
			return park.SnackCounter
		end, function()
			return CFrame.identity
		end, GameConfig.SnackCounterSeats, true),
		newRide("Ferris", park.FerrisRide, function(seat: number)
			local cabin = park.FerrisCabins:FindFirstChild(string.format("FerrisCabin%d", seat))
			return if cabin and cabin:IsA("BasePart") then cabin else nil
		end, ferrisSeatOffset, GameConfig.FerrisCabinCount, false),
		newRide("Swing", park.SwingRide, function(seat: number)
			local swingSeat = park.SwingSeats:FindFirstChild(string.format("SwingSeat%d", seat))
			return if swingSeat and swingSeat:IsA("BasePart") then swingSeat else nil
		end, swingSeatOffset, GameConfig.SwingSeatCount, false),
		newRide("Pirate", park.PirateRide, function()
			return park.PirateShip
		end, pirateSeatOffset, GameConfig.PirateSeatCount, false),
		newRide("Haunted", park.HauntedHouse, function()
			return park.HauntedBody
		end, function()
			return CFrame.identity
		end, GameConfig.HauntedSeatCount, false),
		newRide("Coaster", park.CoasterRide, function(seat: number)
			local car = park.CoasterCars:FindFirstChild(string.format("CoasterCar%d", (seat - 1) // 4 + 1))
			return if car and car:IsA("BasePart") then car else nil
		end, trackSeatOffset("Coaster"), GameConfig.CoasterSeatCount, false),
		newRide("Flume", park.FlumeRide, function(seat: number)
			local car = park.FlumeCars:FindFirstChild(string.format("FlumeCar%d", (seat - 1) // 4 + 1))
			return if car and car:IsA("BasePart") then car else nil
		end, trackSeatOffset("Flume"), GameConfig.FlumeSeatCount, false),
		newRide("Drop", park.DropRide, function()
			return park.DropGondola
		end, dropSeatOffset, GameConfig.DropSeatCount, false),
		newRide("Gift", park.GiftShop, function()
			return park.GiftCounter
		end, function()
			return CFrame.identity
		end, GameConfig.SnackCounterSeats, true),
		newRide("Train", park.TrainRide, function(seat: number)
			local car = park.TrainCars:FindFirstChild(string.format("TrainCar%d", (seat - 1) // 4 + 1))
			return if car and car:IsA("BasePart") then car else nil
		end, trackSeatOffset("Train"), GameConfig.TrainSeatCount, false),
	}
	for key, extra in park.Extras do
		local seats = extra.Seats
		local cars = extra.Cars
		if extra.Kind == "Track" and cars then
			-- Track rides seat four to a car and board only while docked, like the coaster.
			local prefix = (ExtraRides[key] :: any).TrackPrefix :: string
			local carPrefix = (ExtraRides[key] :: any).CarPrefix :: string
			TRACK_RIDES[key] = true
			table.insert(
				rides,
				newRide(key, extra.Ride, function(seat: number)
					local car = cars:FindFirstChild(string.format("%s%d", carPrefix, (seat - 1) // 4 + 1))
					return if car and car:IsA("BasePart") then car else nil
				end, trackSeatOffset(prefix), (GameConfig :: any)[prefix .. "SeatCount"], false)
			)
		elseif extra.Kind == "Shop" then
			local counter = seats[1]
			table.insert(
				rides,
				newRide(key, extra.Ride, function()
					return counter
				end, function()
					return CFrame.identity
				end, GameConfig.SnackCounterSeats, true)
			)
		else
			local offset = ExtraRideService.SeatOffset(key)
			local rideInfo = newRide(key, extra.Ride, function(seat: number)
				return seats[seat]
			end, function()
				return offset
			end, #seats, false)
			if extra.Kind == "Hidden" then
				rideInfo.hidden = true
			end
			table.insert(rides, rideInfo)
		end
	end
	for _, rideInfo in rides do
		if rideInfo.key == "Haunted" then
			rideInfo.hidden = true
		end
		if TRACK_RIDES[rideInfo.key] then
			-- Guests board only while the train is docked.
			rideInfo.canBoard = function(): boolean
				return rideInfo.model:GetAttribute("Docked") == true
			end
		end
		if rideInfo.key == "Ferris" then
			-- Only a cabin near the bottom of its turn can be boarded.
			rideInfo.canBoard = function(seat: number): boolean
				local cabin = rideInfo.seatPart(seat)
				local boardY = rideInfo.model:GetAttribute("BoardY") :: number?
				return cabin ~= nil and boardY ~= nil and cabin.Position.Y <= boardY
			end
		end
	end

	local function fareOf(ride: Ride): number
		local base = (ride.model:GetAttribute("Fare") :: number?) or GameConfig.Rides[ride.key].BaseFare
		local multiplier = (park.ParkFolder:GetAttribute("FareMultiplier") :: number?) or 1
		return math.floor(base * multiplier + 0.5)
	end

	local function firstFreeSeat(ride: Ride): number?
		for seat = 1, ride.seatCount do
			if
				not ride.seatTaken[seat]
				and ride.seatPart(seat) ~= nil
				and (ride.canBoard == nil or ride.canBoard(seat))
			then
				return seat
			end
		end
		return nil
	end

	local function updateQueue(ride: Ride)
		for index, guest in ride.queue do
			guest.slot = ParkLayout.QueueSlot(ride.key, index - 1, guest.jitter)
		end
		ride.model:SetAttribute("QueueLength", #ride.queue)
	end

	local function removeFromQueue(guest: Guest)
		local ride = guest.ride
		if ride == nil then
			return
		end
		local index = table.find(ride.queue, guest)
		if index then
			table.remove(ride.queue, index)
			updateQueue(ride)
		end
		guest.prompt.Enabled = false
	end

	-- The first guest in a ride's line who is standing at their spot. A guest still walking up (from another
	-- zone, say) does not hold the line: whoever has arrived first is let on first.
	local function frontGuest(ride: Ride): Guest?
		for _, guest in ride.queue do
			if guest.arrived and guest.seat == nil and guest.alive then
				return guest
			end
		end
		return nil
	end

	-- Lets the front of a ride's line on. `player` is who allowed it, or nil when the ride's staff did.
	local function tryBoard(ride: Ride, guest: Guest, player: Player?): boolean
		if frontGuest(ride) ~= guest then
			return false
		end
		if ride.model:GetAttribute("IsOperating") ~= true then
			return false
		end

		local seat = firstFreeSeat(ride)
		if seat == nil then
			if player then
				notify(player, "자리가 없어요", "타고 있는 손님이 내리면 다시 허용하세요")
			end
			return false
		end

		ride.seatTaken[seat] = true
		table.remove(ride.queue, table.find(ride.queue, guest) or 1)
		updateQueue(ride)
		guest.seat = seat
		guest.prompt.Enabled = false

		-- The fare is paid the moment a guest boards, so accepting a guest is immediately rewarded.
		local fare = fareOf(ride)
		for _, other in Players:GetPlayers() do
			awardCoins(other, fare)
		end
		popup(guest.root.Position + Vector3.new(0, 9, 0), string.format("+%d %s", fare, currency))
		-- Per-ride totals are kept as attributes so tests (and later a ride rating) can read them.
		ride.model:SetAttribute("Boardings", ((ride.model:GetAttribute("Boardings") :: number?) or 0) + 1)
		park.ParkFolder:SetAttribute(
			"GuestsBoarded",
			((park.ParkFolder:GetAttribute("GuestsBoarded") :: number?) or 0) + 1
		)
		return true
	end

	local function pickRide(previous: Ride?): Ride?
		local open: { Ride } = {}
		for _, ride in rides do
			if ride.model:GetAttribute("IsOperating") == true and #ride.queue < GameConfig.QueueMax then
				table.insert(open, ride)
			end
		end
		-- Prefer a different ride than the one just ridden, but never leave the choice empty.
		if previous and #open > 1 then
			local index = table.find(open, previous)
			if index then
				table.remove(open, index)
			end
		end
		return if #open > 0 then pick(open) else nil
	end

	local function rideOn(guest: Guest, rideInfo: Ride, seat: number)
		local part = rideInfo.seatPart(seat)
		if part == nil or not guest.alive then
			rideInfo.seatTaken[seat] = nil
			return
		end

		if rideInfo.service then
			-- The guest is served where they stand and eats for a moment before making room.
			local eating = 0
			while guest.alive and eating < GameConfig.SnackServeSeconds do
				eating += task.wait(0.5)
			end
			rideInfo.seatTaken[seat] = nil
			return
		end

		if rideInfo.hidden then
			-- The guest walks in through the door and is out of sight until the tour ends.
			guest.root.Anchored = true
			guest.model:PivotTo(CFrame.new(HIDDEN_ORIGIN + Vector3.new(seat * 6, 0, 0)))
			local function countInside()
				local inside = 0
				for _, taken in rideInfo.seatTaken do
					if taken then
						inside += 1
					end
				end
				rideInfo.model:SetAttribute("Occupants", inside)
			end
			countInside()

			local inside = 0
			local tourSeconds = GameConfig.Rides[rideInfo.key].RideSeconds or GameConfig.GuestRideSeconds
			while guest.alive and inside < tourSeconds do
				inside += task.wait(0.5)
			end
			rideInfo.seatTaken[seat] = nil
			countInside()
			if guest.alive and guest.humanoid.Health > 0 then
				guest.model:PivotTo(
					CFrame.new(ParkLayout.QueueSlot(rideInfo.key, 0, guest.jitter * 2) + Vector3.new(0, 4, 0))
				)
				guest.root.Anchored = false
				guest.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
			return
		end

		-- The seat part (rotor root, cup, or bumper car) is anchored, so the weld alone carries the rider.
		guest.humanoid.Sit = true
		guest.root.CFrame = part.CFrame * rideInfo.seatOffset(seat)
		local weld = Instance.new("WeldConstraint")
		weld.Name = "RideWeld"
		weld.Part0 = part
		weld.Part1 = guest.root
		weld.Parent = guest.root

		local elapsed = 0
		local rideSeconds = GameConfig.Rides[rideInfo.key].RideSeconds or GameConfig.GuestRideSeconds
		-- The coaster's trip lasts until the train next docks (`Laps` goes up); RideSeconds is only a safety limit.
		local startLaps = if TRACK_RIDES[rideInfo.key]
			then (rideInfo.model:GetAttribute("Laps") :: number?) or 0
			else nil
		while guest.alive and elapsed < rideSeconds do
			elapsed += task.wait(0.5)
			if startLaps and ((rideInfo.model:GetAttribute("Laps") :: number?) or 0) > startLaps then
				break
			end
		end

		if weld.Parent ~= nil then
			weld:Destroy()
		end
		rideInfo.seatTaken[seat] = nil
		if guest.alive and guest.humanoid.Health > 0 then
			guest.humanoid.Sit = false
			-- Step off at the front of the ride, on the path where the line forms.
			guest.root.CFrame =
				CFrame.new(ParkLayout.QueueSlot(rideInfo.key, 0, guest.jitter * 2) + Vector3.new(0, 4, 0))
			guest.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end

	local function runGuest(guest: Guest)
		local previousRide: Ride? = nil
		local fromKey: string? = nil
		local fromPosition = guest.root.Position

		while guest.alive and guest.ridesTaken < GameConfig.GuestMaxRides do
			local chosen = pickRide(previousRide)
			if chosen == nil then
				break
			end

			guest.ride = chosen
			guest.arrived = false
			guest.seat = nil
			table.insert(chosen.queue, guest)
			updateQueue(chosen)

			followRoute(guest, ParkLayout.RouteToRide(fromKey, fromPosition, guest.lane, chosen.key, guest.slot))

			-- Wait in line, stepping forward as the guests ahead board, until let on or out of patience.
			local waited = 0
			while guest.alive and guest.seat == nil and waited < GameConfig.GuestPatienceSeconds do
				if flatDistance(guest.root.Position, guest.slot) > ARRIVAL_DISTANCE then
					guest.humanoid:MoveTo(guest.slot)
				end
				waited += task.wait(QUEUE_TICK)
			end

			local seat = guest.seat
			if seat == nil then
				removeFromQueue(guest)
				-- Out of patience: head home from this queue, not from wherever the last ride let off.
				fromKey = chosen.key
				fromPosition = guest.root.Position
				break
			end

			rideOn(guest, chosen, seat)
			-- rideOn freed the seat; forget it so the exit cleanup cannot free it again for someone else.
			guest.seat = nil
			guest.ridesTaken += 1
			previousRide = chosen
			fromKey = chosen.key
			fromPosition = guest.root.Position
			if math.random() > GameConfig.GuestExtraRideChance then
				break
			end
		end

		if guest.alive then
			followRoute(guest, ParkLayout.ToCrossing(fromKey, fromPosition, guest.lane))
			followRoute(guest, ParkLayout.CrossingToExit(guest.lane))
		end
	end

	local function spawnGuest()
		local model = createGuestModel()
		if model == nil then
			return
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if humanoid == nil or root == nil or not root:IsA("BasePart") then
			model:Destroy()
			return
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "AcceptPrompt"
		prompt.ActionText = "태우기"
		prompt.ObjectText = "손님"
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 16
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = root

		local lane = math.random(-50, 50) / 10
		local guest: Guest = {
			model = model,
			humanoid = humanoid,
			root = root,
			prompt = prompt,
			lane = lane,
			jitter = math.random(-25, 25) / 10,
			ridesTaken = 0,
			ride = nil,
			slot = Vector3.zero,
			arrived = false,
			seat = nil,
			alive = true,
		}

		prompt.Triggered:Connect(function(player: Player)
			local current = guest.ride
			local character = player.Character
			local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
			if current == nil or playerRoot == nil or not playerRoot:IsA("BasePart") then
				return
			end
			if (playerRoot.Position - guest.root.Position).Magnitude > prompt.MaxActivationDistance + 6 then
				return
			end
			tryBoard(current, guest, player)
		end)

		guestCount += 1
		model:PivotTo(
			CFrame.lookAt(Vector3.new(lane, 3, ParkLayout.EntryZ + 4), Vector3.new(lane, 3, ParkLayout.GateZ))
		)
		model.Parent = guestFolder
		root:SetNetworkOwner(nil)

		task.spawn(function()
			local ok, err = pcall(function()
				runGuest(guest)
			end)
			if not ok then
				warn("[ParkPark] Guest stopped: " .. tostring(err))
			end
			guest.alive = false
			removeFromQueue(guest)
			local seat = guest.seat
			if seat and guest.ride then
				-- A guest removed mid-ride frees the seat they held.
				guest.ride.seatTaken[seat] = nil
			end
			model:Destroy()
			guestCount -= 1
		end)
	end

	-- One loop keeps every line in order: it marks who has reached their spot, shows the accept prompt on
	-- the head of each line while a seat is free, and lets staff board guests automatically.
	task.spawn(function()
		while park.ParkFolder.Parent ~= nil do
			local now = os.clock()
			for _, rideInfo in rides do
				local operating = rideInfo.model:GetAttribute("IsOperating") == true
				local hasSeat = firstFreeSeat(rideInfo) ~= nil
				local fare = fareOf(rideInfo)
				for _, guest in rideInfo.queue do
					guest.arrived = flatDistance(guest.root.Position, guest.slot) <= ARRIVAL_DISTANCE + 1
				end
				local front = frontGuest(rideInfo)
				for _, guest in rideInfo.queue do
					local isHead = guest == front
					guest.prompt.Enabled = isHead and operating and hasSeat
					if isHead then
						guest.prompt.ActionText = if rideInfo.service then "서빙하기" else "태우기"
						guest.prompt.ObjectText =
							string.format("%s 손님 · +%d %s", rideInfo.displayName, fare, currency)
					end
				end

				local interval = (rideInfo.model:GetAttribute("StaffInterval") :: number?) or 0
				local head = front
				if interval > 0 and head and now - rideInfo.lastStaffBoarding >= interval then
					if tryBoard(rideInfo, head, nil) then
						rideInfo.lastStaffBoarding = now
					end
				end
			end
			task.wait(QUEUE_TICK)
		end
	end)

	task.spawn(function()
		while park.ParkFolder.Parent ~= nil do
			local operating = 0
			for _, ride in rides do
				if ride.model:GetAttribute("IsOperating") == true then
					operating += 1
				end
			end
			local crowd = (park.ParkFolder:GetAttribute("CrowdMultiplier") :: number?) or 1
			local capacity = math.min(
				math.floor((GameConfig.MaxGuests + GameConfig.GuestsPerRide * operating) * crowd),
				math.floor(GameConfig.MaxGuestsCap * crowd)
			)
			if park.ParkFolder:GetAttribute("ParkOpen") == true and guestCount < capacity then
				if pickRide(nil) ~= nil then
					spawnGuest()
				end
			end
			task.wait(math.max(GameConfig.GuestSpawnMinSeconds, GameConfig.GuestSpawnSeconds - 0.2 * operating))
		end
	end)
end

return GuestService
