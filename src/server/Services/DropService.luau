--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Runs the drop tower. The gondola (one anchored part with eight welded riders) docks at the bottom for
-- DropDockSeconds with `Docked` true so guests can board, rises smoothly to the top, hangs there with a little
-- shudder, falls freely, and settles with a couple of bounces. Each time it docks it bumps `Laps`, which tells
-- the riders their trip is over (the same contract as the track rides).
local DropService = {}

type DropReferences = {
	DropRide: Model,
	DropGondola: BasePart,
}

local MAX_STEP = 0.1
local BOUNCES = { { height = 2.6, seconds = 0.6 }, { height = 1.0, seconds = 0.4 } }

function DropService.Start(park: DropReferences)
	local ride = park.DropRide
	local gondola = park.DropGondola
	local scale = GameConfig.DropScale
	local rest = gondola.CFrame
	local rise = (GameConfig.DropTopY - GameConfig.DropRestY) * scale

	local phase = "dock"
	local phaseTime = 0
	local laps = 0
	local function setHeight(height: number, shake: number)
		local offset = Vector3.new(math.sin(os.clock() * 61) * shake, height, math.cos(os.clock() * 47) * shake)
		gondola.CFrame = rest + offset
	end
	setHeight(0, 0)
	ride:SetAttribute("Docked", true)
	ride:SetAttribute("Laps", 0)

	local fallSeconds = math.sqrt(2 * rise / GameConfig.DropFallAccel)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		if ride:GetAttribute("IsOperating") ~= true then
			return
		end

		phaseTime += math.min(deltaTime, MAX_STEP)
		if phase == "dock" then
			if phaseTime >= GameConfig.DropDockSeconds then
				phase, phaseTime = "lift", 0
				ride:SetAttribute("Docked", false)
			end
		elseif phase == "lift" then
			local t = math.min(phaseTime / GameConfig.DropLiftSeconds, 1)
			-- Ease in and out so the climb feels heavy at first and slows near the top.
			setHeight(rise * (t * t * (3 - 2 * t)), 0)
			if t >= 1 then
				phase, phaseTime = "hold", 0
			end
		elseif phase == "hold" then
			setHeight(rise, 0.25)
			if phaseTime >= GameConfig.DropHoldSeconds then
				phase, phaseTime = "fall", 0
			end
		elseif phase == "fall" then
			local t = math.min(phaseTime / fallSeconds, 1)
			setHeight(rise * (1 - t * t), 0)
			if t >= 1 then
				phase, phaseTime = "bounce1", 0
			end
		elseif phase == "bounce1" or phase == "bounce2" then
			local bounce = BOUNCES[if phase == "bounce1" then 1 else 2]
			local t = math.min(phaseTime / bounce.seconds, 1)
			setHeight(bounce.height * math.sin(math.pi * t), 0)
			if t >= 1 then
				if phase == "bounce1" then
					phase, phaseTime = "bounce2", 0
				else
					phase, phaseTime = "dock", 0
					setHeight(0, 0)
					laps += 1
					ride:SetAttribute("Laps", laps)
					ride:SetAttribute("Docked", true)
				end
			end
		end
	end)
end

return DropService
