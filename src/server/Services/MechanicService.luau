--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- The repair shop beside the generator: holding E hires the next mechanic level (GameConfig.MechanicCosts),
-- paid by the player who does it. The level is the park attribute `Mechanics` (saved with the park); PowerService
-- uses it to bring the power back sooner when nobody flips the generator.
local MechanicService = {}

type SpendCoins = (Player, number) -> boolean
type Notify = (Player, string, string) -> ()

function MechanicService.Start(park: { ParkFolder: Folder }, spendCoins: SpendCoins, notify: Notify)
	local folder = park.ParkFolder
	if folder:GetAttribute("Mechanics") == nil then
		folder:SetAttribute("Mechanics", 0)
	end
	local position = ParkLayout.MechanicShopPosition
	local palette = GameConfig.Palette

	local model = Instance.new("Model")
	model.Name = "MechanicShop"
	local function part(name: string, size: Vector3, offset: Vector3, color: Color3): Part
		local piece = Instance.new("Part")
		piece.Name = name
		piece.Size = size
		piece.Position = position + offset
		piece.Color = color
		piece.Material = Enum.Material.SmoothPlastic
		piece.Anchored = true
		piece.Parent = model
		return piece
	end
	part("Base", Vector3.new(9, 1, 6), Vector3.new(0, 0.5, 0), palette.Cream)
	local counter = part("Counter", Vector3.new(8, 3, 3), Vector3.new(0, 2.5, 0), palette.Gold)
	part("Roof", Vector3.new(10, 0.6, 7), Vector3.new(0, 8, 0), palette.Mint)
	for _, x in { -4.2, 4.2 } do
		part("Post", Vector3.new(0.6, 6.5, 0.6), Vector3.new(x, 4.5, 2.6), palette.Coral)
	end
	local wrench = part("Wrench", Vector3.new(0.8, 4, 0.8), Vector3.new(0, 5.2, 0), palette.Ink)
	wrench.CFrame = CFrame.new(position + Vector3.new(0, 5.2, 0)) * CFrame.Angles(0, 0, math.rad(40))
	local sign = part("SignBoard", Vector3.new(9, 3, 0.4), Vector3.new(0, 10.5, 3), palette.Cream)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 42)
	billboard.StudsOffset = Vector3.new(0, 4.2, 0)
	billboard.MaxDistance = 20
	billboard.LightInfluence = 0
	billboard.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = "정비소"
	label.TextColor3 = palette.Ink
	label.TextStrokeColor3 = palette.Cream
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Parent = billboard
	model.PrimaryPart = counter
	model.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MechanicPrompt"
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	local function refresh()
		local level = (folder:GetAttribute("Mechanics") :: number?) or 0
		local cost = GameConfig.MechanicCosts[level + 1]
		if cost then
			prompt.ActionText = string.format("정비사 %d명째 고용", level + 1)
			prompt.ObjectText = string.format(
				"%d %s · 정전이 %d초로",
				cost,
				GameConfig.CurrencyDisplayName,
				GameConfig.MechanicTimeouts[level + 1]
			)
			prompt.Enabled = true
		else
			prompt.ActionText = "정비사가 가득 찼어요"
			prompt.ObjectText = "정비소"
			prompt.Enabled = false
		end
	end
	folder:GetAttributeChangedSignal("Mechanics"):Connect(refresh)
	refresh()

	prompt.Triggered:Connect(function(player: Player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") or (root.Position - counter.Position).Magnitude > 24 then
			return
		end
		local level = (folder:GetAttribute("Mechanics") :: number?) or 0
		local cost = GameConfig.MechanicCosts[level + 1]
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
		folder:SetAttribute("Mechanics", level + 1)
		notify(
			player,
			"정비사를 고용했어요",
			string.format(
				"정전이 나도 %d초 안에 전기가 돌아와요",
				GameConfig.MechanicTimeouts[level + 1]
			)
		)
	end)
end

return MechanicService
