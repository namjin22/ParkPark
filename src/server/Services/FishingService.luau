--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActiveIncome = require(script.Parent.ActiveIncome)
local MissionService = require(script.Parent.MissionService)
local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Fishing: the beach ponds of the water zone get a fishing spot. Holding E casts for a few seconds and then pays a
-- catch worth some seconds of the park's income (GameConfig.Active.Fish). Ponds only exist where scenery was placed,
-- so this runs after DecorService and simply looks for `DecorPond` models.
local FishingService = {}

type AwardCoins = (Player, number) -> boolean
type Popup = (Vector3, string) -> ()

function FishingService.Start(park: { ParkFolder: Folder }, awardCoins: AwardCoins, popup: Popup)
	local folder = park.ParkFolder
	local decor = folder:FindFirstChild("Decor")
	if decor == nil then
		return
	end
	local random = Random.new(11)
	local total = 0
	for _, entry in GameConfig.Active.Fish do
		total += entry.Weight
	end

	local function cast(player: Player, position: Vector3)
		MissionService.Report(player, "Fish")
		local roll = random:NextNumber(0, total)
		for _, entry in GameConfig.Active.Fish do
			roll -= entry.Weight
			if roll <= 0 then
				local amount = if entry.Seconds > 0 then ActiveIncome.Value(folder, entry.Seconds) else 0
				if amount > 0 then
					awardCoins(player, amount)
				end
				popup(
					position + Vector3.new(0, 6, 0),
					if amount > 0 then string.format("%s +%d", entry.Name, amount) else entry.Name
				)
				return
			end
		end
	end

	for _, pond in decor:GetChildren() do
		if pond.Name == "DecorPond" and pond:IsA("Model") then
			local position = pond:GetPivot().Position
			local spot = Instance.new("Part")
			spot.Name = "FishingSpot"
			spot.Size = Vector3.new(2, 2, 2)
			spot.Transparency = 1
			spot.Anchored = true
			spot.CanCollide = false
			spot.CanQuery = false
			spot.Position = position + Vector3.new(0, 2, 0)
			spot.Parent = pond
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "낚시하기"
			prompt.ObjectText = "연못"
			prompt.HoldDuration = GameConfig.Active.FishCastSeconds
			prompt.MaxActivationDistance = 30
			prompt.RequiresLineOfSight = false
			prompt.Parent = spot
			prompt.Triggered:Connect(function(player: Player)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") and (root.Position - position).Magnitude <= 40 then
					cast(player, position)
				end
			end)
		end
	end
end

return FishingService
