--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- First-session order: clean the entrance (earn coins) -> repair the carousel (spend coins,
-- RideService) -> open the park at the gate (GuestService then brings guests in).
local ParkProgressionService = {}

type ParkReferences = {
	ParkFolder: Folder,
	Entrance: Model,
	Debris: Model,
	CleanupTarget: BasePart,
	CleanupPrompt: ProximityPrompt,
	RepairPrompt: ProximityPrompt,
	Carousel: Model,
	GateRope: Model,
	GatePrompt: ProximityPrompt,
}

type AwardCoins = (Player, number) -> boolean
type ApplyEntranceRestored = (Model) -> ()
type Notify = (Player, string, string) -> ()

local function hideModel(model: Model)
	for _, descendant in model:GetDescendants() do
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
	awardCoins: AwardCoins,
	applyEntranceRestored: ApplyEntranceRestored,
	notify: Notify
)
	local entranceCleared = park.ParkFolder:GetAttribute("EntranceCleared") == true
	if park.ParkFolder:GetAttribute("ParkOpen") == nil then
		park.ParkFolder:SetAttribute("ParkOpen", false)
	end

	park.CleanupPrompt.Enabled = not entranceCleared
	park.RepairPrompt.Enabled = entranceCleared and park.Carousel:GetAttribute("IsRepaired") ~= true
	if entranceCleared then
		hideModel(park.Debris)
		park.CleanupPrompt.ActionText = "정리 완료"
	end

	park.CleanupPrompt.Triggered:Connect(function(player: Player)
		if entranceCleared or not canUsePrompt(player, park.CleanupTarget, park.CleanupPrompt) then
			return
		end
		if not awardCoins(player, GameConfig.EntranceCleanupReward) then
			return
		end

		entranceCleared = true
		park.ParkFolder:SetAttribute("EntranceCleared", true)
		park.Debris:SetAttribute("IsCleared", true)
		hideModel(park.Debris)
		applyEntranceRestored(park.Entrance)
		park.CleanupPrompt.ActionText = "정리 완료"
		park.CleanupPrompt.Enabled = false
		park.RepairPrompt.Enabled = true
		notify(
			player,
			"입구 청소 완료!",
			string.format("+%d %s", GameConfig.EntranceCleanupReward, GameConfig.CurrencyDisplayName)
		)
	end)

	-- Opening needs a working ride; the gate prompt appears once the carousel is repaired.
	local function refreshGatePrompt()
		park.GatePrompt.Enabled = park.Carousel:GetAttribute("IsRepaired") == true
			and park.ParkFolder:GetAttribute("ParkOpen") ~= true
	end
	park.Carousel:GetAttributeChangedSignal("IsRepaired"):Connect(refreshGatePrompt)
	refreshGatePrompt()
	if park.ParkFolder:GetAttribute("ParkOpen") == true then
		hideModel(park.GateRope)
	end

	local gateAnchor = park.GatePrompt.Parent
	park.GatePrompt.Triggered:Connect(function(player: Player)
		if
			park.ParkFolder:GetAttribute("ParkOpen") == true
			or park.Carousel:GetAttribute("IsRepaired") ~= true
			or gateAnchor == nil
			or not gateAnchor:IsA("BasePart")
			or not canUsePrompt(player, gateAnchor, park.GatePrompt)
		then
			return
		end

		park.ParkFolder:SetAttribute("ParkOpen", true)
		hideModel(park.GateRope)
		park.GatePrompt.Enabled = false
		for _, other in Players:GetPlayers() do
			notify(other, "파크 파크 개장!", "손님이 곧 도착해요")
		end
	end)
end

return ParkProgressionService
