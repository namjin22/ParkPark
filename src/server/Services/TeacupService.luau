--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Turns the teacup hub while the ride operates and spins every cup on its own turntable. Cups are
-- anchored parts positioned each Heartbeat from the hub's CFrame (guests are welded to a cup, so they
-- turn with it). Rides that still use the legacy single-mesh rotor have no cups and are left alone.
local TeacupService = {}

type TeacupReferences = {
	TeacupsRide: Model,
	TeacupsRotor: Model,
	TeacupCups: Model?,
}

local MAX_STEP = 0.1

function TeacupService.Start(park: TeacupReferences)
	local cupsModel = park.TeacupCups
	local hub = park.TeacupsRotor.PrimaryPart
	if cupsModel == nil or hub == nil then
		return
	end

	local baseCFrame = hub.CFrame
	local cups: { { part: BasePart, offset: CFrame, phase: number } } = {}
	for index = 1, GameConfig.TeacupCupCount do
		local part = cupsModel:FindFirstChild(string.format("TeacupCup%d", index))
		if part and part:IsA("BasePart") then
			table.insert(cups, {
				part = part,
				-- The cup's placement on the hub, measured once while the ride is at rest.
				offset = baseCFrame:ToObjectSpace(part.CFrame),
				phase = (index - 1) * 1.7,
			})
		else
			warn(string.format("[ParkPark] TeacupCups is missing TeacupCup%d", index))
		end
	end

	local hubAngle = 0
	local spinAngle = 0
	local hubSpeed = 2 * math.pi / GameConfig.TeacupsRotationSeconds
	local spinSpeed = 2 * math.pi / GameConfig.TeacupCupSpinSeconds

	RunService.Heartbeat:Connect(function(deltaTime: number)
		if park.TeacupsRide:GetAttribute("IsOperating") ~= true then
			return
		end

		local step = math.min(deltaTime, MAX_STEP)
		hubAngle = (hubAngle + hubSpeed * step) % (2 * math.pi)
		spinAngle = (spinAngle + spinSpeed * step) % (2 * math.pi)
		hub.CFrame = baseCFrame * CFrame.Angles(0, hubAngle, 0)
		for _, cup in cups do
			cup.part.CFrame = hub.CFrame * cup.offset * CFrame.Angles(0, spinAngle + cup.phase, 0)
		end
	end)
end

return TeacupService
