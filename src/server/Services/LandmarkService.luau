--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Permanent plaza buildings (GameConfig.Landmarks): a ticket booth, a sponsor board and a VIP lounge. Each is bought in
-- two tiers by holding E at its plot; the tier is the park attribute `Landmark_<key>` (saved with the park) and the
-- summed bonus is published as `LandmarkBonus`, which IncomeService multiplies into every ride's income. A building
-- needs the park to be open and, for the later ones, a zone to be open first. Models are simple built shapes; a
-- `Landmark<Key>` template in ParkParkAssets replaces the shape when one is imported.
local LandmarkService = {}

type SpendCoins = (Player, number) -> boolean
type Notify = (Player, string, string) -> ()
type FindTemplate = (string) -> Model?

local function newPart(model: Model, name: string, size: Vector3, offset: Vector3, color: Color3): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.Position = offset
	piece.Color = color
	piece.Material = Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.Parent = model
	return piece
end

-- Builds the standing shape for a key at tier 1 or 2 (tier 2 adds gold trim and lights), front toward local +Z.
local function buildShape(key: string, tier: number): Model
	local palette = GameConfig.Palette
	local model = Instance.new("Model")
	model.Name = "Landmark" .. key
	local base = newPart(model, "Base", Vector3.new(10, 0.4, 7), Vector3.new(0, 0.2, 0), palette.Cream)
	model.PrimaryPart = base
	local trim = if tier >= 2 then palette.Gold else palette.Cream
	if key == "Ticket" then
		newPart(model, "Back", Vector3.new(7, 6, 0.6), Vector3.new(0, 3.4, -2.4), palette.Mint)
		newPart(model, "SideL", Vector3.new(0.6, 6, 4.4), Vector3.new(-3.2, 3.4, -0.4), palette.Mint)
		newPart(model, "SideR", Vector3.new(0.6, 6, 4.4), Vector3.new(3.2, 3.4, -0.4), palette.Mint)
		newPart(model, "Counter", Vector3.new(7, 2.4, 1.2), Vector3.new(0, 1.6, 1.8), palette.Coral)
		newPart(model, "Awning", Vector3.new(8.4, 0.6, 6), Vector3.new(0, 6.6, 0.2), trim)
		newPart(model, "Window", Vector3.new(4, 2.2, 0.2), Vector3.new(0, 4.4, 1.9), palette.Ink).Transparency = 0.35
	elseif key == "Sponsor" then
		for _, x in { -4, 4 } do
			newPart(model, "Post", Vector3.new(0.7, 9, 0.7), Vector3.new(x, 4.7, 0), palette.Ink)
		end
		newPart(model, "Board", Vector3.new(9.4, 5, 0.5), Vector3.new(0, 7, 0), palette.Cream)
		newPart(model, "Frame", Vector3.new(10, 0.5, 0.7), Vector3.new(0, 9.7, 0), trim)
		newPart(model, "FrameLow", Vector3.new(10, 0.5, 0.7), Vector3.new(0, 4.3, 0), trim)
	else
		for _, x in { -4, 4 } do
			for _, z in { -2.4, 2.4 } do
				newPart(model, "Column", Vector3.new(0.9, 7, 0.9), Vector3.new(x, 3.9, z), trim)
			end
		end
		newPart(model, "Rug", Vector3.new(5, 0.1, 6), Vector3.new(0, 0.45, 0.6), palette.Coral)
		newPart(model, "Roof", Vector3.new(10.6, 0.7, 7.6), Vector3.new(0, 7.7, 0), palette.Gold)
		newPart(model, "Couch", Vector3.new(6, 1.6, 1.4), Vector3.new(0, 1.2, -1.8), palette.Mint)
	end
	if tier >= 2 then
		local light = Instance.new("PointLight")
		light.Color = palette.Gold
		light.Range = 18
		light.Brightness = 1.2
		light.Parent = base
	end
	return model
end

function LandmarkService.Start(
	park: { ParkFolder: Folder },
	spendCoins: SpendCoins,
	notify: Notify,
	findTemplate: FindTemplate
)
	local folder = park.ParkFolder
	local palette = GameConfig.Palette

	local function tierOf(key: string): number
		return (folder:GetAttribute("Landmark_" .. key) :: number?) or 0
	end

	local function publishBonus()
		local total = 0
		for key, landmark in GameConfig.Landmarks do
			local tier = tierOf(key)
			if tier > 0 then
				total += landmark.Bonus[math.min(tier, #landmark.Bonus)]
			end
		end
		folder:SetAttribute("LandmarkBonus", total)
	end

	local holder = Instance.new("Folder")
	holder.Name = "Landmarks"
	holder.Parent = folder

	for _, key in GameConfig.LandmarkOrder do
		local landmark = GameConfig.Landmarks[key]
		local spot = ParkLayout.Landmarks[key]
		if landmark and spot then
			if folder:GetAttribute("Landmark_" .. key) == nil then
				folder:SetAttribute("Landmark_" .. key, 0)
			end
			local pivot = CFrame.lookAt(spot.Position, spot.Position - spot.Facing) + Vector3.new(0, 0.2, 0)

			-- The plot: a small sign post that stays through all tiers and carries the prompt and the label.
			local plot = Instance.new("Model")
			plot.Name = "LandmarkPlot_" .. key
			local post = newPart(plot, "Post", Vector3.new(0.6, 5, 0.6), Vector3.new(0, 2.5, 0), palette.Ink)
			local sign = newPart(plot, "Sign", Vector3.new(6, 2, 0.3), Vector3.new(0, 5.4, 0), palette.Cream)
			plot.PrimaryPart = post
			-- Stands to the side of the building, on the side the front faces, so the prompt is reachable.
			plot:PivotTo(pivot * CFrame.new(-6.5, 0, 4.2))
			plot.Parent = holder

			local billboard = Instance.new("BillboardGui")
			billboard.Size = UDim2.fromOffset(150, 44)
			billboard.StudsOffset = Vector3.new(0, 2, 0)
			billboard.MaxDistance = 60
			billboard.LightInfluence = 0
			billboard.Parent = sign
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBold
			label.TextScaled = true
			label.TextColor3 = palette.Ink
			label.TextStrokeColor3 = palette.Cream
			label.TextStrokeTransparency = 0.2
			label.Parent = billboard

			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "LandmarkPrompt"
			prompt.HoldDuration = 0.8
			prompt.MaxActivationDistance = 14
			prompt.RequiresLineOfSight = false
			prompt.Parent = sign

			local standing: Model? = nil
			local shownTier = -1

			local function blockedReason(): string?
				if folder:GetAttribute("ParkOpen") ~= true then
					return "먼저 공원을 여세요"
				end
				if landmark.Zone and folder:GetAttribute("Zone_" .. landmark.Zone) ~= true then
					return string.format("먼저 %s을 여세요", GameConfig.ZoneNames[landmark.Zone] or landmark.Zone)
				end
				return nil
			end

			local function refresh()
				local tier = tierOf(key)
				if tier ~= shownTier then
					shownTier = tier
					if standing then
						standing:Destroy()
						standing = nil
					end
					if tier > 0 then
						local template = findTemplate("Landmark" .. key)
						local model = if template then template:Clone() else buildShape(key, tier)
						model.Name = "Landmark" .. key
						model:PivotTo(pivot)
						model.Parent = holder
						standing = model
					end
				end
				local cost = landmark.Costs[tier + 1]
				local reason = blockedReason()
				if cost == nil then
					label.Text = string.format("%s 최대", landmark.Name)
					prompt.Enabled = false
				elseif reason then
					label.Text = landmark.Name
					prompt.ActionText = reason
					prompt.ObjectText = landmark.Name
					prompt.Enabled = false
				else
					label.Text = string.format("%s %d단계", landmark.Name, tier + 1)
					prompt.ActionText = if tier == 0 then "건설" else "확장"
					prompt.ObjectText = string.format(
						"%d %s · 모든 수입 +%d%%",
						cost,
						GameConfig.CurrencyDisplayName,
						math.floor(landmark.Bonus[tier + 1] * 100 + 0.5)
					)
					prompt.Enabled = true
				end
			end
			folder:GetAttributeChangedSignal("Landmark_" .. key):Connect(refresh)
			folder:GetAttributeChangedSignal("ParkOpen"):Connect(refresh)
			if landmark.Zone then
				folder:GetAttributeChangedSignal("Zone_" .. landmark.Zone):Connect(refresh)
			end
			refresh()

			prompt.Triggered:Connect(function(player: Player)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root == nil or not root:IsA("BasePart") or (root.Position - sign.Position).Magnitude > 24 then
					return
				end
				if blockedReason() then
					return
				end
				local tier = tierOf(key)
				local cost = landmark.Costs[tier + 1]
				if cost == nil then
					return
				end
				if not spendCoins(player, cost) then
					notify(
						player,
						string.format("%s이 부족해요", GameConfig.CurrencyDisplayName),
						string.format("%d %s이 필요해요", cost, GameConfig.CurrencyDisplayName)
					)
					return
				end
				folder:SetAttribute("Landmark_" .. key, tier + 1)
				publishBonus()
				notify(
					player,
					string.format("%s %d단계", landmark.Name, tier + 1),
					string.format(
						"모든 수입이 합쳐서 %d%% 늘었어요",
						math.floor((folder:GetAttribute("LandmarkBonus") :: number) * 100 + 0.5)
					)
				)
			end)
		end
	end
	publishBonus()
end

return LandmarkService
