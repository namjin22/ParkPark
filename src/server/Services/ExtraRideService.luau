--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))
local ExtraRides = require(Config:WaitForChild("ExtraRides"))
local ParkBuilder = require(script.Parent:WaitForChild("ParkBuilder"))
local TrackService = require(script.Parent:WaitForChild("TrackService"))

-- Builds and runs the data-driven attractions listed in ExtraRides: it clones each ride's template (or makes a
-- graybox when the template has not been imported), places it at ParkLayout.Rides[key].Pivot, applies saved
-- state, and animates it. Unlocking, repairs, upgrades, power, and guests are handled by RideService,
-- PowerService, and GuestService through `park.Extras`.
local ExtraRideService = {}

type ExtraSpec = ExtraRides.ExtraSpec

local MAX_STEP = 0.1
local FADED = Color3.fromRGB(122, 112, 98)

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = FADED
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part:SetAttribute("FadedColor", FADED)
	part:SetAttribute("RestoredColor", color)
	if shape then
		part.Shape = shape
	end
	part.Parent = parent
	return part
end

local function hide(part: BasePart)
	part.Transparency = 1
	part.CastShadow = false
end

local function makeSeatMarker(model: Model, index: number, position: Vector3)
	local seat = makePart(model, string.format("Seat%d", index), Vector3.new(1, 0.2, 1), position, FADED, nil)
	seat.CanCollide = false
	hide(seat)
end

-- Local frame (before the pivot): the ride sits at the origin; track rides are drawn for the half-turn their
-- pivot applies, with the station on the south side.
local function buildGraybox(key: string, spec: ExtraSpec): Model
	local model = Instance.new("Model")
	model.Name = GameConfig.Rides[key].ModelName
	model:SetAttribute("IsGraybox", true)
	local scale = spec.Scale
	local pivot = makePart(model, "ParkPivot", Vector3.new(0.1, 0.1, 0.1), Vector3.zero, FADED, nil)
	pivot.CanCollide = false
	pivot.CanTouch = false
	pivot.CanQuery = false
	hide(pivot)
	model.PrimaryPart = pivot
	local consolePosition = Vector3.new(-14, 1.5, ParkLayout.Rides[key].PlatformRadius - 6)

	if spec.Kind == "Spinner" or spec.Kind == "Carousel" then
		local radius = spec.HubRadius or 8.6
		local orbit = spec.SeatOrbit or 5.6
		local hub = makePart(
			model,
			"Hub",
			Vector3.new(0.9 * scale, radius * 2 * scale, radius * 2 * scale),
			Vector3.new(0, 0.45 * scale, 0),
			Color3.fromRGB(240, 190, 80),
			Enum.PartType.Cylinder
		)
		hub.CFrame = CFrame.new(0, 0.45 * scale, 0) * CFrame.Angles(0, 0, math.pi / 2)
		for index = 1, spec.SeatCount do
			local angle = (index - 1) * 2 * math.pi / spec.SeatCount
			local seat = makePart(
				model,
				string.format("Seat%d", index),
				Vector3.new(1.2 * scale, 1.6 * scale, 2 * scale),
				Vector3.new(math.cos(angle) * orbit * scale, 1.6 * scale, math.sin(angle) * orbit * scale),
				Color3.fromRGB(255, 220, 90),
				Enum.PartType.Ball
			)
			seat.CanCollide = false
		end
		local collider = makePart(
			model,
			"Collider",
			Vector3.new(2, (radius + 0.6) * 2 * scale, (radius + 0.6) * 2 * scale),
			Vector3.new(0, 1, 0),
			FADED,
			Enum.PartType.Cylinder
		)
		collider.CFrame = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.pi / 2)
		hide(collider)
	elseif spec.Kind == "Bounce" then
		makePart(
			model,
			"Pad",
			Vector3.new(13 * scale, 1 * scale, 13 * scale),
			Vector3.new(0, 0.5 * scale, 0),
			Color3.fromRGB(240, 190, 80),
			nil
		)
		for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
			local tower = makePart(
				model,
				"Tower",
				Vector3.new(2.3 * scale, 4 * scale, 2.3 * scale),
				Vector3.new(corner.X * 6.5 * scale, 3 * scale, corner.Z * 6.5 * scale),
				Color3.fromRGB(235, 122, 108),
				nil
			)
			tower.CanCollide = false
		end
		for index = 1, spec.SeatCount do
			local angle = (index - 1) * 2 * math.pi / spec.SeatCount
			makeSeatMarker(
				model,
				index,
				Vector3.new(math.cos(angle) * 3.2 * scale, 1.05 * scale, math.sin(angle) * 3.2 * scale)
			)
		end
		local collider = makePart(
			model,
			"Collider",
			Vector3.new(14 * scale, 6 * scale, 14 * scale),
			Vector3.new(0, 3 * scale, 0),
			FADED,
			nil
		)
		hide(collider)
	elseif spec.Kind == "Hidden" then
		makePart(
			model,
			"Pad",
			Vector3.new(31 * scale, 6.4 * scale, 31 * scale),
			Vector3.new(0, 3.2 * scale, 0),
			Color3.fromRGB(96, 178, 120),
			nil
		)
		for index = 1, spec.SeatCount do
			makeSeatMarker(model, index, Vector3.new(index, 1, 0))
		end
		consolePosition = Vector3.new(-24, 1.5, 35)
	else
		-- A track ride: segments along the generated centre line, a station slab, and a box per car.
		local path = require(Config:WaitForChild(spec.PathModule :: string)) :: any
		local points: { Vector3 } = path.Points
		for index = 1, #points, 2 do
			local from = points[index] * scale
			local to = points[(index + 1) % #points + 1] * scale
			local length = (to - from).Magnitude
			if length > 0.1 then
				local segment = makePart(
					model,
					"TrackSegment",
					Vector3.new(1.6 * scale, 0.5 * scale, length + 0.3),
					(from + to) / 2,
					Color3.fromRGB(235, 122, 108),
					nil
				)
				segment.CFrame = CFrame.lookAt((from + to) / 2, to)
				segment.CanCollide = false
			end
		end
		makePart(
			model,
			"Station",
			Vector3.new(16.4, 0.7, 2.9) * scale,
			Vector3.new(0, 0.35 * scale, -8.2 * scale),
			Color3.fromRGB(255, 232, 190),
			nil
		)
		local cars = Instance.new("Model")
		cars.Name = spec.CarsName :: string
		cars.Parent = model
		for index = 1, (GameConfig :: any)[(spec.TrackPrefix :: string) .. "CarCount"] do
			local car = makePart(
				cars,
				string.format("%s%d", spec.CarPrefix :: string, index),
				Vector3.new(2.2, 1.59, 3.96) * scale,
				points[path.StationIndex] * scale,
				Color3.fromRGB(96, 178, 146),
				nil
			)
			car.CanCollide = false
		end
		consolePosition = Vector3.new(18, 1.5, -(8.2 * scale + 10))
	end

	local console = makePart(model, "Console", Vector3.new(2, 3, 2), consolePosition, Color3.fromRGB(91, 87, 79), nil)
	console.Material = Enum.Material.Slate
	return model
end

local function applySaved(savedRides: { [string]: any }?, key: string, model: Model)
	local saved = if savedRides then savedRides[key] else nil
	if saved then
		for attribute, value in saved do
			model:SetAttribute(attribute, value)
		end
	end
end

function ExtraRideService.Build(park: ParkBuilder.References, savedRides: { [string]: any }?)
	for key, spec in ExtraRides do
		local template = ParkBuilder.FindDecorTemplate(spec.Template)
		local model: Model
		if template then
			model = template:Clone()
			model.Name = spec.Template
			model:SetAttribute("IsGraybox", false)
		else
			model = buildGraybox(key, spec)
		end
		applySaved(savedRides, key, model)
		for _, attribute in { "IsUnlocked", "IsRepaired", "IsOperating" } do
			if model:GetAttribute(attribute) == nil then
				model:SetAttribute(attribute, false)
			end
		end

		local console = model:FindFirstChild("Console", true)
		if console == nil or not console:IsA("BasePart") then
			error(string.format("[ParkPark] %s needs a Console part", spec.Template))
		end

		local seats: { BasePart } = {}
		local carsModel: Model? = nil
		if spec.Kind == "Track" then
			local found = model:FindFirstChild(spec.CarsName :: string, true)
			if found == nil or not found:IsA("Model") then
				error(string.format("[ParkPark] %s needs a %s model", spec.Template, spec.CarsName :: string))
			end
			carsModel = found
			-- TrackService moves the cars every frame, so they stay anchored and non-solid.
			for _, descendant in found:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.Anchored = true
					descendant.CanCollide = false
					descendant.CanTouch = false
					descendant.CanQuery = false
				end
			end
		else
			-- Parts that animate stay anchored and are never solid (only the colliders are).
			for index = 1, spec.SeatCount do
				local seat = model:FindFirstChild(string.format("Seat%d", index), true)
				if seat == nil or not seat:IsA("BasePart") then
					error(string.format("[ParkPark] %s is missing Seat%d", spec.Template, index))
				end
				seat.Anchored = true
				seat.CanCollide = false
				seat.CanTouch = false
				seat.CanQuery = false
				table.insert(seats, seat)
			end
		end
		local hubInstance = model:FindFirstChild("Hub", true)
		local hub: BasePart? = nil
		if hubInstance and hubInstance:IsA("BasePart") then
			hub = hubInstance
			hubInstance.Anchored = true
			hubInstance.CanCollide = false
		end
		model.Parent = park.ParkFolder
		model:PivotTo(CFrame.new(ParkLayout.Rides[key].Pivot) * CFrame.Angles(0, math.rad(spec.PivotYaw or 0), 0))
		ParkBuilder.ApplyExtraAppearance(model, model:GetAttribute("IsRepaired") == true)
		park.Extras[key] =
			{ Ride = model, Console = console, Seats = seats, Hub = hub, Cars = carsModel, Kind = spec.Kind }
	end
end

-- A seat offset for GuestService: the rider's root relative to the seat part's centre.
function ExtraRideService.SeatOffset(key: string): CFrame
	local spec = ExtraRides[key]
	return CFrame.new(0, spec.SeatLift * spec.Scale + spec.RiderHip, 0)
		* CFrame.Angles(0, math.rad(spec.RiderYaw or 0), 0)
end

function ExtraRideService.Start(park: ParkBuilder.References)
	for key, extra in park.Extras do
		local spec = ExtraRides[key]
		local ride = extra.Ride
		local hub = extra.Hub
		if spec.Kind == "Track" then
			TrackService.Start({
				Ride = ride,
				Cars = extra.Cars :: Model,
				Path = require(Config:WaitForChild(spec.PathModule :: string)) :: any,
				CarPrefix = spec.CarPrefix :: string,
				ConfigPrefix = spec.TrackPrefix :: string,
			})
		elseif (spec.Kind == "Spinner" or spec.Kind == "Carousel") and hub then
			local baseCFrame = hub.CFrame
			local offsets: { CFrame } = {}
			for _, seat in extra.Seats do
				table.insert(offsets, baseCFrame:ToObjectSpace(seat.CFrame))
			end
			local hubSpeed = 2 * math.pi / (spec.HubSeconds or 16)
			local spinning = spec.Kind == "Spinner"
			local spinSpeed = 2 * math.pi / (spec.SpinSeconds or 7)
			local height = spec.BounceHeight or 0
			local period = spec.BouncePeriod or 1
			local hubAngle, spinAngle, clock = 0, 0, 0
			RunService.Heartbeat:Connect(function(deltaTime: number)
				if ride:GetAttribute("IsOperating") ~= true then
					return
				end
				local step = math.min(deltaTime, MAX_STEP)
				hubAngle = (hubAngle + hubSpeed * step) % (2 * math.pi)
				spinAngle = (spinAngle + spinSpeed * step) % (2 * math.pi)
				clock += step
				hub.CFrame = baseCFrame * CFrame.Angles(0, hubAngle, 0)
				for index, seat in extra.Seats do
					local frame = hub.CFrame * offsets[index]
					if spinning then
						frame = frame * CFrame.Angles(0, spinAngle + (index - 1) * 1.7, 0)
					elseif height > 0 then
						-- Neighbouring animals rise as the others fall, like carousel horses.
						local lift = (math.sin(clock / period * 2 * math.pi + index * math.pi) * 0.5 + 0.5) * height
						frame = frame + hub.CFrame.UpVector * lift
					end
					seat.CFrame = frame
				end
			end)
		elseif spec.Kind == "Bounce" then
			local rest: { CFrame } = {}
			for _, seat in extra.Seats do
				table.insert(rest, seat.CFrame)
			end
			local height = spec.BounceHeight or 6
			local period = spec.BouncePeriod or 1
			local clock = 0
			RunService.Heartbeat:Connect(function(deltaTime: number)
				if ride:GetAttribute("IsOperating") ~= true then
					return
				end
				clock += math.min(deltaTime, MAX_STEP)
				for index, seat in extra.Seats do
					local phase = clock / period * math.pi + (index - 1) * 2 * math.pi / #extra.Seats
					seat.CFrame = rest[index] + Vector3.new(0, math.abs(math.sin(phase)) * height, 0)
				end
			end)
		end
	end
end

return ExtraRideService
