--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Drives the bumper cars around the rink once the ride operates: cars wander, turn now and then,
-- bounce off the rail, and bump into each other. Cars stay anchored (guests are welded to them),
-- so this is a small 2D simulation on the rink plane written straight to each car's CFrame.
local BumperCarService = {}

type BumperReferences = {
	BumperRide: Model,
	BumperCars: Model,
}

type Car = {
	part: BasePart,
	position: Vector2,
	direction: Vector2,
	facing: number,
	height: number,
	steerAt: number,
}

local STEER_MIN_SECONDS = 1.2
local STEER_MAX_SECONDS = 3.2
local STEER_MAX_ANGLE = math.rad(70)
local TURN_RATE = math.rad(200)
local MAX_STEP = 0.1

local function rotate(direction: Vector2, angle: number): Vector2
	local cosine, sine = math.cos(angle), math.sin(angle)
	return Vector2.new(direction.X * cosine - direction.Y * sine, direction.X * sine + direction.Y * cosine)
end

local function angleOf(direction: Vector2): number
	return math.atan2(direction.Y, direction.X)
end

local function shortestAngle(from: number, to: number): number
	return math.atan2(math.sin(to - from), math.cos(to - from))
end

function BumperCarService.Start(park: BumperReferences)
	-- The rink and the cars have separate scales: cars are sized for the guests riding them.
	local carRadius = GameConfig.BumperCarRadius * GameConfig.BumperCarScale
	local maxRadius = GameConfig.BumperArenaRadius * GameConfig.BumperScale - carRadius
	local speed = GameConfig.BumperCarSpeed
	local ridePivot = park.BumperRide:GetPivot()

	local cars: { Car } = {}
	for index = 1, GameConfig.BumperSeatCount do
		local part = park.BumperCars:FindFirstChild(string.format("BumperCar%d", index))
		if part and part:IsA("BasePart") then
			local localPosition = ridePivot:PointToObjectSpace(part.Position)
			local localLook = ridePivot:VectorToObjectSpace(part.CFrame.LookVector)
			local direction = Vector2.new(localLook.X, localLook.Z)
			if direction.Magnitude < 0.01 then
				direction = Vector2.new(1, 0)
			end
			table.insert(cars, {
				part = part,
				position = Vector2.new(localPosition.X, localPosition.Z),
				direction = direction.Unit,
				facing = angleOf(direction),
				height = localPosition.Y,
				steerAt = os.clock() + math.random() * STEER_MAX_SECONDS,
			})
		else
			warn(string.format("[ParkPark] BumperCarsRide is missing BumperCar%d", index))
		end
	end
	if #cars == 0 then
		return
	end

	local function bounceOffRail(car: Car)
		local distance = car.position.Magnitude
		if distance <= maxRadius then
			return
		end

		local inward = -car.position.Unit
		car.position = car.position.Unit * maxRadius
		local approach = car.direction:Dot(inward)
		if approach < 0 then
			car.direction = (car.direction - 2 * approach * inward).Unit
		end
	end

	local function bumpCars()
		local minimumDistance = carRadius * 2
		for first = 1, #cars - 1 do
			for second = first + 1, #cars do
				local a, b = cars[first], cars[second]
				local offset = b.position - a.position
				local distance = offset.Magnitude
				if distance < minimumDistance and distance > 0.001 then
					local normal = offset / distance
					local overlap = minimumDistance - distance
					a.position -= normal * overlap * 0.5
					b.position += normal * overlap * 0.5

					-- Equal-mass elastic bump: swap the velocity components along the contact normal.
					local relative = (a.direction - b.direction):Dot(normal)
					if relative > 0 then
						a.direction = (a.direction - normal * relative).Unit
						b.direction = (b.direction + normal * relative).Unit
					end
				end
			end
		end
	end

	local function step(deltaTime: number)
		local now = os.clock()
		for _, car in cars do
			if now >= car.steerAt then
				car.direction = rotate(car.direction, (math.random() * 2 - 1) * STEER_MAX_ANGLE)
				car.steerAt = now + STEER_MIN_SECONDS + math.random() * (STEER_MAX_SECONDS - STEER_MIN_SECONDS)
			end
			car.position += car.direction * speed * deltaTime
		end
		bumpCars()

		for _, car in cars do
			bounceOffRail(car)
			local turn = shortestAngle(car.facing, angleOf(car.direction))
			car.facing += math.clamp(turn, -TURN_RATE * deltaTime, TURN_RATE * deltaTime)
			-- The car's front is local -Z, so face along the direction of travel.
			local yaw = math.atan2(-math.cos(car.facing), -math.sin(car.facing))
			car.part.CFrame = ridePivot
				* CFrame.new(car.position.X, car.height, car.position.Y)
				* CFrame.Angles(0, yaw, 0)
		end
	end

	RunService.Heartbeat:Connect(function(deltaTime: number)
		if park.BumperRide:GetAttribute("IsOperating") ~= true then
			return
		end
		step(math.min(deltaTime, MAX_STEP))
	end)
end

return BumperCarService
