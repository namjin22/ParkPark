--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Swings the pirate ship back and forth on its axle while the ride operates. The ship is one anchored part
-- turned about the axle (the mesh's origin, which sits above its bounding-box centre) every Heartbeat;
-- guests are welded to it, so they swing with it. The swing widens and narrows over PirateCycleSeconds.
local PirateService = {}

type PirateReferences = {
	PirateRide: Model,
	PirateShip: BasePart,
}

local MAX_STEP = 0.1

function PirateService.Start(park: PirateReferences)
	local ship = park.PirateShip
	local restCFrame = ship.CFrame
	local scale = GameConfig.PirateScale

	-- The axle is where the OBJ origin is: the ship part's centre offset back up by the mesh's centre height.
	local axleWorld = restCFrame:PointToWorldSpace(Vector3.new(0, -GameConfig.PirateShipCenterY * scale, 0))
	local axle = CFrame.new(axleWorld) * restCFrame.Rotation
	local restFromAxle = axle:ToObjectSpace(restCFrame)

	local phase = 0
	local elapsed = 0
	local minAngle = math.rad(GameConfig.PirateMinAngle)
	local maxAngle = math.rad(GameConfig.PirateMaxAngle)

	RunService.Heartbeat:Connect(function(deltaTime: number)
		if park.PirateRide:GetAttribute("IsOperating") ~= true then
			return
		end

		local step = math.min(deltaTime, MAX_STEP)
		elapsed += step
		phase = (phase + step * 2 * math.pi / GameConfig.PirateSwingSeconds) % (2 * math.pi)
		local amplitude = minAngle
			+ (maxAngle - minAngle) * (0.5 - 0.5 * math.cos(2 * math.pi * elapsed / GameConfig.PirateCycleSeconds))
		ship.CFrame = axle * CFrame.Angles(amplitude * math.sin(phase), 0, 0) * restFromAxle
	end)
end

return PirateService
