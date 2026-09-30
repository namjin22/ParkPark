--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local CoasterPath = require(Config:WaitForChild("CoasterPath"))

-- Runs the roller coaster train round its track while the ride operates. The train is `CoasterCarCount` cars
-- following one centre line (the generated CoasterPath, in unscaled OBJ units). It docks at the station for
-- CoasterDockSeconds, lets guests board only then (`Docked` on the ride), climbs the lift at a steady crawl, and
-- otherwise rolls like a real coaster: its speed comes from its height below the top of the lift. Each time the
-- train docks it bumps `Laps`, which is how riders know their trip is over.
local CoasterService = {}

type CoasterReferences = {
	CoasterRide: Model,
	CoasterCars: Model,
}

local MAX_STEP = 0.1
local ACCELERATION = 30

function CoasterService.Start(park: CoasterReferences)
	local ride = park.CoasterRide
	local scale = GameConfig.CoasterScale
	local origin = ride:GetPivot()
	local points: { Vector3 } = {}
	for _, point in CoasterPath.Points do
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

	local stationDistance = lengthAt[CoasterPath.StationIndex]
	local liftStart = lengthAt[CoasterPath.LiftStartIndex]
	local liftEnd = lengthAt[CoasterPath.LiftEndIndex]
	local topHeight = GameConfig.CoasterTopHeight * scale

	local cars: { BasePart } = {}
	for index = 1, GameConfig.CoasterCarCount do
		local car = park.CoasterCars:FindFirstChild(string.format("CoasterCar%d", index))
		if car and car:IsA("BasePart") then
			table.insert(cars, car)
		else
			warn(string.format("[ParkPark] CoasterCars is missing CoasterCar%d", index))
		end
	end
	if #cars == 0 then
		return
	end

	local spacing = GameConfig.CoasterCarSpacing * scale
	local function place(leadDistance: number)
		for index, car in cars do
			local position, tangent = pointAt(leadDistance - (index - 1) * spacing)
			local world = origin:PointToWorldSpace(position)
			local look = origin:VectorToWorldSpace(tangent)
			local frame = CFrame.lookAt(world, world + look)
			car.CFrame = frame * CFrame.new(0, GameConfig.CoasterCarCenterY * scale, 0)
		end
	end

	-- The lead car starts docked, with the train stretched back along the station straight.
	local distance = stationDistance
	local speed = 0
	local docked = true
	local dockedUntil = os.clock() + GameConfig.CoasterDockSeconds
	local laps = 0
	place(distance)
	ride:SetAttribute("Docked", true)
	ride:SetAttribute("Laps", 0)

	local function targetSpeed(): number
		local _, _, index = pointAt(distance)
		local height = points[index].Y
		-- Ahead of the station the train brakes to a crawl so it stops exactly at the dock.
		local toStation = (stationDistance - distance) % total
		local approach = GameConfig.CoasterStationSpeed + toStation * 0.7
		if distance >= liftStart and distance <= liftEnd then
			return GameConfig.CoasterLiftSpeed
		end
		local rolling =
			math.sqrt(GameConfig.CoasterMinSpeed ^ 2 + 2 * GameConfig.CoasterGravity * math.max(0, topHeight - height))
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
			dockedUntil = os.clock() + GameConfig.CoasterDockSeconds
			laps += 1
			ride:SetAttribute("Laps", laps)
			ride:SetAttribute("Docked", true)
		end
		place(distance)
	end)
end

return CoasterService
