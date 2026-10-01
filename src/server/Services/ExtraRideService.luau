--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))
local ExtraRides = require(Config:WaitForChild("ExtraRides"))
local ParkBuilder = require(script.Parent:WaitForChild("ParkBuilder"))

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

-- Local frame (before the pivot): the ride sits at the origin, its line runs toward +Z, the console sits beside it.
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

	if spec.Kind == "Spinner" then
		local hub = makePart(
			model,
			"Hub",
			Vector3.new(0.9 * scale, 17.2 * scale, 17.2 * scale),
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
				Vector3.new(3 * scale, 2.8 * scale, 3.4 * scale),
				Vector3.new(math.cos(angle) * 5.6 * scale, 2.4 * scale, math.sin(angle) * 5.6 * scale),
				Color3.fromRGB(255, 220, 90),
				Enum.PartType.Ball
			)
			seat.CanCollide = false
		end
		local collider = makePart(
			model,
			"Collider",
			Vector3.new(2, 17.8 * scale, 17.8 * scale),
			Vector3.new(0, 1, 0),
			FADED,
			Enum.PartType.Cylinder
		)
		collider.CFrame = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.pi / 2)
		hide(collider)
	else
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
			local seat = makePart(
				model,
				string.format("Seat%d", index),
				Vector3.new(1, 0.2, 1),
				Vector3.new(math.cos(angle) * 3.2 * scale, 1.05 * scale, math.sin(angle) * 3.2 * scale),
				FADED,
				nil
			)
			seat.CanCollide = false
			hide(seat)
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
		-- Parts that animate stay anchored and are never solid (only the colliders are).
		local seats: { BasePart } = {}
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
		local hubInstance = model:FindFirstChild("Hub", true)
		local hub: BasePart? = nil
		if hubInstance and hubInstance:IsA("BasePart") then
			hub = hubInstance
			hubInstance.Anchored = true
			hubInstance.CanCollide = false
		end
		model.Parent = park.ParkFolder
		model:PivotTo(CFrame.new(ParkLayout.Rides[key].Pivot))
		ParkBuilder.ApplyExtraAppearance(model, model:GetAttribute("IsRepaired") == true)
		park.Extras[key] = { Ride = model, Console = console, Seats = seats, Hub = hub }
	end
end

-- A seat offset for GuestService: the rider's root relative to the seat part's centre.
function ExtraRideService.SeatOffset(key: string): CFrame
	local spec = ExtraRides[key]
	return CFrame.new(0, spec.SeatLift * spec.Scale + spec.RiderHip, 0)
end

function ExtraRideService.Start(park: ParkBuilder.References)
	for key, extra in park.Extras do
		local spec = ExtraRides[key]
		local ride = extra.Ride
		local hub = extra.Hub
		if spec.Kind == "Spinner" and hub then
			local baseCFrame = hub.CFrame
			local offsets: { CFrame } = {}
			for _, seat in extra.Seats do
				table.insert(offsets, baseCFrame:ToObjectSpace(seat.CFrame))
			end
			local hubSpeed = 2 * math.pi / (spec.HubSeconds or 16)
			local spinSpeed = 2 * math.pi / (spec.SpinSeconds or 7)
			local hubAngle, spinAngle = 0, 0
			RunService.Heartbeat:Connect(function(deltaTime: number)
				if ride:GetAttribute("IsOperating") ~= true then
					return
				end
				local step = math.min(deltaTime, MAX_STEP)
				hubAngle = (hubAngle + hubSpeed * step) % (2 * math.pi)
				spinAngle = (spinAngle + spinSpeed * step) % (2 * math.pi)
				hub.CFrame = baseCFrame * CFrame.Angles(0, hubAngle, 0)
				for index, seat in extra.Seats do
					seat.CFrame = hub.CFrame * offsets[index] * CFrame.Angles(0, spinAngle + (index - 1) * 1.7, 0)
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
