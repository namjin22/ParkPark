--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local RideService = {}

type RideReferences = {
	Carousel: Model,
	CarouselRotor: Model,
	RepairConsole: BasePart,
	RepairPrompt: ProximityPrompt,
}

type AwardTickets = (Player, number) -> boolean
type ApplyRepairedAppearance = (Model) -> ()

function RideService.Start(
	park: RideReferences,
	awardTickets: AwardTickets,
	applyRepairedAppearance: ApplyRepairedAppearance
)
	local rewardedPlayers: { [number]: boolean } = {}
	local carouselRepaired = park.Carousel:GetAttribute("IsRepaired") == true
	local rotationStarted = false

	local function startCarousel()
		if rotationStarted then
			return
		end

		local rotorRoot = park.CarouselRotor.PrimaryPart
		if rotorRoot == nil then
			warn("[ParkPark] Carousel rotor has no PrimaryPart")
			return
		end

		rotationStarted = true
		park.Carousel:SetAttribute("IsOperating", true)
		local baseCFrame = rotorRoot.CFrame
		task.spawn(function()
			local angle = 0
			local quarterTurnDuration = GameConfig.CarouselRotationSeconds / 4
			while rotorRoot.Parent ~= nil and park.Carousel:GetAttribute("IsRepaired") == true do
				angle = (angle + math.pi / 2) % (math.pi * 2)
				local tween = TweenService:Create(
					rotorRoot,
					TweenInfo.new(quarterTurnDuration, Enum.EasingStyle.Linear),
					{ CFrame = baseCFrame * CFrame.Angles(0, angle, 0) }
				)
				tween:Play()
				if tween.Completed:Wait() ~= Enum.PlaybackState.Completed then
					return
				end
			end
		end)
	end

	if carouselRepaired then
		park.RepairPrompt.ActionText = "수리 완료"
		startCarousel()
	end

	park.RepairPrompt.Triggered:Connect(function(player: Player)
		if player.Parent ~= Players or rewardedPlayers[player.UserId] then
			return
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid == nil or humanoid.Health <= 0 or rootPart == nil or not rootPart:IsA("BasePart") then
			return
		end
		if
			(rootPart.Position - park.RepairConsole.Position).Magnitude
			> park.RepairPrompt.MaxActivationDistance + 2
		then
			return
		end

		if not awardTickets(player, GameConfig.CarouselRepairReward) then
			return
		end
		rewardedPlayers[player.UserId] = true

		if not carouselRepaired then
			carouselRepaired = true
			applyRepairedAppearance(park.Carousel)
			park.Carousel:SetAttribute("IsRepaired", true)
			park.RepairPrompt.ActionText = "수리 완료"
			startCarousel()
		end
	end)
end

return RideService
