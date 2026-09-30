--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Turns the Ferris wheel while the ride operates and carries its cabins around the rim. The cabins are
-- anchored parts moved every Heartbeat (guests are welded to a cabin), and they keep their orientation, so
-- they always hang upright. `BoardY` tells GuestService which cabins are low enough to board.
local FerrisService = {}

type FerrisReferences = {
	FerrisRide: Model,
	FerrisWheel: BasePart,
	FerrisCabins: Model,
}

local MAX_STEP = 0.1

function FerrisService.Start(park: FerrisReferences)
	local wheel = park.FerrisWheel
	local baseCFrame = wheel.CFrame

	-- Each cabin's centre relative to the hub, measured once while the wheel is at rest.
	local cabins: { { part: BasePart, offset: Vector3, rotation: CFrame } } = {}
	for index = 1, GameConfig.FerrisCabinCount do
		local part = park.FerrisCabins:FindFirstChild(string.format("FerrisCabin%d", index))
		if part and part:IsA("BasePart") then
			table.insert(cabins, {
				part = part,
				offset = baseCFrame:PointToObjectSpace(part.Position),
				rotation = part.CFrame.Rotation,
			})
		else
			warn(string.format("[ParkPark] FerrisCabins is missing FerrisCabin%d", index))
		end
	end
	if #cabins == 0 then
		return
	end

	-- The lowest a cabin's centre ever gets, and the height up to which it counts as at the boarding spot.
	local lowest = math.huge
	for step = 0, 359 do
		local rolled = baseCFrame * CFrame.Angles(0, 0, math.rad(step))
		lowest = math.min(lowest, rolled:PointToWorldSpace(cabins[1].offset).Y)
	end
	park.FerrisRide:SetAttribute(
		"BoardY",
		lowest + GameConfig.FerrisBoardingWindow * GameConfig.FerrisRadius * GameConfig.FerrisScale
	)

	local angle = 0
	local speed = 2 * math.pi / GameConfig.FerrisRotationSeconds
	RunService.Heartbeat:Connect(function(deltaTime: number)
		if park.FerrisRide:GetAttribute("IsOperating") ~= true then
			return
		end

		angle = (angle + speed * math.min(deltaTime, MAX_STEP)) % (2 * math.pi)
		local rolled = baseCFrame * CFrame.Angles(0, 0, angle)
		wheel.CFrame = rolled
		for _, cabin in cabins do
			cabin.part.CFrame = CFrame.new(rolled:PointToWorldSpace(cabin.offset)) * cabin.rotation
		end
	end)
end

return FerrisService
