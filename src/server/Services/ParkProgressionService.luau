--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local ParkProgressionService = {}

type ParkReferences = {
	ParkFolder: Folder,
	Entrance: Model,
	Debris: Model,
	CleanupTarget: BasePart,
	CleanupPrompt: ProximityPrompt,
	RepairPrompt: ProximityPrompt,
}

type AwardTickets = (Player, number) -> boolean
type ApplyEntranceRestored = (Model) -> ()

local function hideDebris(debris: Model)
	for _, descendant in debris:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
end

local function canUsePrompt(player: Player, target: BasePart, prompt: ProximityPrompt): boolean
	if player.Parent ~= Players then
		return false
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or rootPart == nil or not rootPart:IsA("BasePart") then
		return false
	end

	return (rootPart.Position - target.Position).Magnitude <= prompt.MaxActivationDistance + 2
end

function ParkProgressionService.Start(
	park: ParkReferences,
	awardTickets: AwardTickets,
	applyEntranceRestored: ApplyEntranceRestored
)
	local entranceCleared = park.ParkFolder:GetAttribute("EntranceCleared") == true
	park.CleanupPrompt.Enabled = not entranceCleared
	park.RepairPrompt.Enabled = entranceCleared

	if entranceCleared then
		hideDebris(park.Debris)
		park.CleanupPrompt.ActionText = "정리 완료"
	end

	park.CleanupPrompt.Triggered:Connect(function(player: Player)
		if entranceCleared or not canUsePrompt(player, park.CleanupTarget, park.CleanupPrompt) then
			return
		end
		if not awardTickets(player, GameConfig.EntranceCleanupReward) then
			return
		end

		entranceCleared = true
		park.ParkFolder:SetAttribute("EntranceCleared", true)
		park.Debris:SetAttribute("IsCleared", true)
		hideDebris(park.Debris)
		applyEntranceRestored(park.Entrance)
		park.CleanupPrompt.ActionText = "정리 완료"
		park.CleanupPrompt.Enabled = false
		park.RepairPrompt.Enabled = true
	end)
end

return ParkProgressionService
