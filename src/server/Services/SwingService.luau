--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Turns the swing ride's crown while it operates and swings the chairs out as it speeds up. The crown and
-- the seats are anchored parts moved every Heartbeat; guests are welded to a seat, so they swing with it.
-- The crown's speed rises and falls over SwingCycleSeconds, and each seat's outward angle follows the speed
-- (with a little lag), like the real ride. `SwingSeatFlip` in GameConfig covers a mesh imported facing backwards.
local SwingService = {}

type SwingReferences = {
	SwingRide: Model,
	SwingCrown: BasePart,
	SwingSeats: Model,
}

local MAX_STEP = 0.1
local UP = Vector3.new(0, 1, 0)

function SwingService.Start(park: SwingReferences)
	local crown = park.SwingCrown
	local baseCFrame = crown.CFrame
	local scale = GameConfig.SwingScale
	-- The imported mesh is turned half a turn about its centre, so the centre offset flips in x and z.
	local seatCenter = Vector3.new(
		-GameConfig.SwingSeatCenterX,
		GameConfig.SwingSeatCenterY,
		-GameConfig.SwingSeatCenterZ
	) * scale

	-- Each seat's anchor relative to the crown, measured once while the ride is at rest (the seat hangs
	-- straight down, unrotated, so its anchor is its centre minus the mesh's centre offset).
	local seats: { { part: BasePart, anchor: Vector3 } } = {}
	for index = 1, GameConfig.SwingSeatCount do
		local part = park.SwingSeats:FindFirstChild(string.format("SwingSeat%d", index))
		if part and part:IsA("BasePart") then
			local anchorWorld = part.Position - part.CFrame:VectorToWorldSpace(seatCenter)
			table.insert(seats, { part = part, anchor = baseCFrame:PointToObjectSpace(anchorWorld) })
		else
			warn(string.format("[ParkPark] SwingSeats is missing SwingSeat%d", index))
		end
	end
	if #seats == 0 then
		return
	end

	local turn = 0
	local elapsed = 0
	local swing = 0
	local maxAngle = math.rad(GameConfig.SwingMaxAngle)
	local topSpeed = 2 * math.pi / GameConfig.SwingRotationSeconds

	RunService.Heartbeat:Connect(function(deltaTime: number)
		if park.SwingRide:GetAttribute("IsOperating") ~= true then
			return
		end

		local step = math.min(deltaTime, MAX_STEP)
		elapsed += step
		-- Speed cycles between about 15% and 100% of the top speed.
		local level = 0.575 + 0.425 * math.sin(2 * math.pi * elapsed / GameConfig.SwingCycleSeconds - math.pi / 2)
		turn = (turn + topSpeed * level * step) % (2 * math.pi)
		local targetSwing = maxAngle * level * level
		swing += (targetSwing - swing) * math.min(1, step * 2.5)

		local crownCFrame = baseCFrame * CFrame.Angles(0, turn, 0)
		crown.CFrame = crownCFrame
		local axis = crownCFrame.Position
		for _, seat in seats do
			local anchor = crownCFrame:PointToWorldSpace(seat.anchor)
			local outward = Vector3.new(anchor.X - axis.X, 0, anchor.Z - axis.Z)
			outward = if outward.Magnitude > 1e-3 then outward.Unit else Vector3.new(1, 0, 0)
			-- The direction the seat travels in, and the hanging chair's up vector tilted outward.
			local travel = Vector3.new(outward.Z, 0, -outward.X)
			local up = math.cos(swing) * UP - math.sin(swing) * outward
			local look = if GameConfig.SwingSeatFlip then -travel else travel
			local rotation = CFrame.fromMatrix(Vector3.zero, look:Cross(up), up)
			seat.part.CFrame = CFrame.new(anchor + rotation:VectorToWorldSpace(seatCenter)) * rotation
		end
	end)
end

return SwingService
