--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local RideService = {}

type RideReferences = {
	Carousel: Model,
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
	if carouselRepaired then
		park.RepairPrompt.ActionText = "수리 완료"
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
		end
	end)
end

return RideService
