--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- The decor shop opposite the speed shop: holding E buys the next decoration for the next free plot around the
-- plaza (ParkLayout.DecorPlots). The count is the park attribute `PlotsBought` (saved with the park, and the
-- bought plots are rebuilt from it); every plot adds GameConfig.DecorPlotFareBonus to all fares.
local DecorShopService = {}

type SpendCoins = (Player, number) -> boolean
type Notify = (Player, string, string) -> ()

local function cost(bought: number): number
	return math.floor(GameConfig.DecorPlotBaseCost * GameConfig.DecorPlotGrowth ^ bought / 50 + 0.5) * 50
end

function DecorShopService.Start(
	park: { ParkFolder: Folder },
	spendCoins: SpendCoins,
	notify: Notify,
	findTemplate: (string) -> Model?
)
	local folder = park.ParkFolder
	if folder:GetAttribute("PlotsBought") == nil then
		folder:SetAttribute("PlotsBought", 0)
	end
	local position = ParkLayout.DecorShopPosition
	local palette = GameConfig.Palette
	local plots = ParkLayout.DecorPlots

	local placed = Instance.new("Folder")
	placed.Name = "DecorPlots"
	placed.Parent = folder

	local function placeOne(index: number)
		local kinds = GameConfig.DecorPlotKinds
		local kind = kinds[(index - 1) % #kinds + 1]
		local template = findTemplate(kind)
		local model: Model
		if template then
			model = template:Clone()
		else
			model = Instance.new("Model")
			local ball = Instance.new("Part")
			ball.Shape = Enum.PartType.Ball
			ball.Size = Vector3.new(5, 5, 5)
			ball.Position = Vector3.new(0, 3, 0)
			ball.Color = palette.Coral
			ball.Anchored = true
			ball.Parent = model
			model.PrimaryPart = ball
		end
		model.Name = kind
		model:PivotTo(CFrame.new(plots[index]) * CFrame.Angles(0, index * 1.3, 0))
		model.Parent = placed
	end

	local shop = Instance.new("Model")
	shop.Name = "DecorShop"
	local function part(name: string, size: Vector3, offset: Vector3, color: Color3): Part
		local piece = Instance.new("Part")
		piece.Name = name
		piece.Size = size
		piece.Position = position + offset
		piece.Color = color
		piece.Material = Enum.Material.SmoothPlastic
		piece.Anchored = true
		piece.Parent = shop
		return piece
	end
	part("Base", Vector3.new(9, 1, 6), Vector3.new(0, 0.5, 0), palette.Cream)
	local counter = part("Counter", Vector3.new(8, 3, 3), Vector3.new(0, 2.5, 0), palette.Coral)
	part("Roof", Vector3.new(10, 0.6, 7), Vector3.new(0, 8, 0), palette.Gold)
	for _, x in { -4.2, 4.2 } do
		part("Post", Vector3.new(0.6, 6.5, 0.6), Vector3.new(x, 4.5, 2.6), palette.Mint)
	end
	local flower = part("Flower", Vector3.new(3, 3, 3), Vector3.new(0, 5, 0), palette.Gold)
	flower.Shape = Enum.PartType.Ball
	local sign = part("SignBoard", Vector3.new(9, 3, 0.4), Vector3.new(0, 10.5, 3), palette.Cream)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(230, 70)
	billboard.StudsOffset = Vector3.new(0, 4.2, 0)
	billboard.MaxDistance = 130
	billboard.LightInfluence = 0
	billboard.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = "꾸미기 상점"
	label.TextColor3 = palette.Ink
	label.TextStrokeColor3 = palette.Cream
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Parent = billboard
	shop.PrimaryPart = counter
	shop.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DecorPrompt"
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	local shown = 0
	local function refresh()
		local bought = (folder:GetAttribute("PlotsBought") :: number?) or 0
		while shown < math.min(bought, #plots) do
			shown += 1
			placeOne(shown)
		end
		if bought < #plots then
			prompt.ActionText = string.format("꾸미기 %d/%d", bought + 1, #plots)
			prompt.ObjectText = string.format(
				"%d %s · 모든 요금 +%d%%",
				cost(bought),
				GameConfig.CurrencyDisplayName,
				math.floor((bought + 1) * GameConfig.DecorPlotFareBonus * 100 + 0.5)
			)
			prompt.Enabled = true
		else
			prompt.ActionText = "광장이 가득 찼어요"
			prompt.ObjectText = "꾸미기 상점"
			prompt.Enabled = false
		end
	end
	folder:GetAttributeChangedSignal("PlotsBought"):Connect(refresh)
	refresh()

	prompt.Triggered:Connect(function(player: Player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") or (root.Position - counter.Position).Magnitude > 24 then
			return
		end
		local bought = (folder:GetAttribute("PlotsBought") :: number?) or 0
		if bought >= #plots then
			return
		end
		local price = cost(bought)
		if not spendCoins(player, price) then
			notify(
				player,
				string.format("%s이 부족해요", GameConfig.CurrencyDisplayName),
				string.format("%d %s이 필요해요", price, GameConfig.CurrencyDisplayName)
			)
			return
		end
		folder:SetAttribute("PlotsBought", bought + 1)
		notify(
			player,
			"광장이 예뻐졌어요!",
			string.format(
				"모든 요금이 %d%% 올랐어요",
				math.floor((bought + 1) * GameConfig.DecorPlotFareBonus * 100 + 0.5)
			)
		)
	end)
end

return DecorShopService
