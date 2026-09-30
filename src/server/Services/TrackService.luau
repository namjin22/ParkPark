--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Runs a train of cars round a closed track while a ride operates: the roller coaster, and any other ride that
-- follows a generated centre line (the log flume). The cars follow the path (points in unscaled OBJ units),
-- dock at the station for `DockSeconds` (guests board only then: `Docked` on the ride), climb the lift at a steady
-- crawl, and otherwise roll like a real coaster, with speed from their height below the top of the lift.
-- Each time the train docks it bumps `Laps`, which is how riders know their trip is over.
local TrackService = {}

export type TrackPath = {
	StationIndex: number,
	LiftStartIndex: number,
	LiftEndIndex: number,
	Points: { Vector3 },
}

-- The car model's parts are named `<CarPrefix>1 .. <CarPrefix>N`; numbers are read from GameConfig as
-- `<ConfigPrefix>Scale`, `<ConfigPrefix>CarCount`, and so on.
export type TrackDefinition = {
	Ride: Model,
	Cars: Model,
	Path: TrackPath,
	CarPrefix: string,
	ConfigPrefix: string,
}

local MAX_STEP = 0.1
local ACCELERATION = 30

local function setting(prefix: string, name: string): number
	return (GameConfig :: any)[prefix .. name]
end

function TrackService.Start(definition: TrackDefinition)
	local ride = definition.Ride
	local prefix = definition.ConfigPrefix
	local scale = setting(prefix, "Scale")
	local origin = ride:GetPivot()
	local points: { Vector3 } = {}
	for _, point in definition.Path.Points do
		table.insert(points, point * scale)
	end
	local count = #points

	-- Cumulative arc length at each sample, and the total round the loop.
	local lengthAt: { number } = { 0 }
	for index = 1, count do
		local nextPoint = points[index % count + 1]
		lengthAt[index + 1] = lengthAt[index] + (nextPoint - points[index]).Magnitude
	end
	local total = lengthAt[count + 1]

	local function pointAt(distance: number): (Vector3, Vector3, number)
		distance = distance % total
		-- Binary search for the segment that contains this distance.
		local low, high = 1, count
		while low < high do
			local middle = (low + high + 1) // 2
			if lengthAt[middle] <= distance then
				low = middle
			else
				high = middle - 1
			end
		end
		local from = points[low]
		local to = points[low % count + 1]
		local span = lengthAt[low + 1] - lengthAt[low]
		local fraction = if span > 0 then (distance - lengthAt[low]) / span else 0
		return from:Lerp(to, fraction), (to - from).Unit, low
	end

	local stationDistance = lengthAt[definition.Path.StationIndex]
	local liftStart = lengthAt[definition.Path.LiftStartIndex]
	local liftEnd = lengthAt[definition.Path.LiftEndIndex]
	local topHeight = setting(prefix, "TopHeight") * scale
	local liftSpeed = setting(prefix, "LiftSpeed")
	local stationSpeed = setting(prefix, "StationSpeed")
	local minSpeed = setting(prefix, "MinSpeed")
	local gravity = setting(prefix, "Gravity")
	local dockSeconds = setting(prefix, "DockSeconds")

	local cars: { BasePart } = {}
	for index = 1, setting(prefix, "CarCount") do
		local car = definition.Cars:FindFirstChild(string.format("%s%d", definition.CarPrefix, index))
		if car and car:IsA("BasePart") then
			table.insert(cars, car)
		else
			warn(string.format("[ParkPark] %s is missing %s%d", definition.Cars.Name, definition.CarPrefix, index))
		end
	end
	if #cars == 0 then
		return
	end

	local spacing = setting(prefix, "CarSpacing") * scale
	local centerY = setting(prefix, "CarCenterY") * scale
	local function place(leadDistance: number)
		for index, car in cars do
			local position, tangent = pointAt(leadDistance - (index - 1) * spacing)
			local world = origin:PointToWorldSpace(position)
			local look = origin:VectorToWorldSpace(tangent)
			local frame = CFrame.lookAt(world, world + look)
			car.CFrame = frame * CFrame.new(0, centerY, 0)
		end
	end

	-- The lead car starts docked, with the train stretched back along the station straight.
	local distance = stationDistance
	local speed = 0
	local docked = true
	local dockedUntil = os.clock() + dockSeconds
	local laps = 0
	place(distance)
	ride:SetAttribute("Docked", true)
	ride:SetAttribute("Laps", 0)

	local function targetSpeed(): number
		local _, _, index = pointAt(distance)
		local height = points[index].Y
		-- Ahead of the station the train brakes to a crawl so it stops exactly at the dock.
		local toStation = (stationDistance - distance) % total
		local approach = stationSpeed + toStation * 0.7
		if distance >= liftStart and distance <= liftEnd then
			return liftSpeed
		end
		local rolling = math.sqrt(minSpeed ^ 2 + 2 * gravity * math.max(0, topHeight - height))
		return math.min(rolling, approach)
	end

	RunService.Heartbeat:Connect(function(deltaTime: number)
		if ride:GetAttribute("IsOperating") ~= true then
			return
		end

		local step = math.min(deltaTime, MAX_STEP)
		if docked then
			if os.clock() >= dockedUntil then
				docked = false
				ride:SetAttribute("Docked", false)
			end
			return
		end

		local target = targetSpeed()
		speed += math.clamp(target - speed, -ACCELERATION * step, ACCELERATION * step)
		local previous = distance
		distance = (distance + speed * step) % total

		-- Crossing the station point: stop there and open the doors.
		local crossed = (previous < stationDistance and distance >= stationDistance)
			or (previous > distance and (stationDistance > previous or stationDistance <= distance))
		if crossed then
			distance = stationDistance
			speed = 0
			docked = true
			dockedUntil = os.clock() + dockSeconds
			laps += 1
			ride:SetAttribute("Laps", laps)
			ride:SetAttribute("Docked", true)
		end
		place(distance)
	end)
end

return TrackService
