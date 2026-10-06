--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- The speed shop by the spawn path: holding E buys the next speed level (GameConfig.SpeedLevelCosts). The level
-- is saved with the player and published as their `SpeedLevel` attribute; TravelService turns it into walk
-- speed, and the client shows the next price on the prompt.
local SpeedShopService = {}

type SpendCoins = (Player, number) -> boolean
type Notify = (Player, string, string) -> ()

function SpeedShopService.Start(
	park: { ParkFolder: Folder },
	spendCoins: SpendCoins,
	notify: Notify,
	getLevel: (Player) -> number,
	setLevel: (Player, number) -> ()
)
	local position = ParkLayout.SpeedShopPosition
	local model = Instance.new("Model")
	model.Name = "SpeedShop"

	local function part(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material): Part
		local piece = Instance.new("Part")
		piece.Name = name
		piece.Size = size
		piece.Position = position + offset
		piece.Color = color
		piece.Material = material
		piece.Anchored = true
		piece.TopSurface = Enum.SurfaceType.Smooth
		piece.BottomSurface = Enum.SurfaceType.Smooth
		piece.Parent = model
		return piece
	end
	local palette = GameConfig.Palette
	part("Base", Vector3.new(9, 1, 6), Vector3.new(0, 0.5, 0), palette.Cream, Enum.Material.SmoothPlastic)
	local counter =
		part("Counter", Vector3.new(8, 3, 3), Vector3.new(0, 2.5, 0), palette.Mint, Enum.Material.SmoothPlastic)
	part("Roof", Vector3.new(10, 0.6, 7), Vector3.new(0, 8, 0), palette.Coral, Enum.Material.SmoothPlastic)
	for _, x in { -4.2, 4.2 } do
		part("Post", Vector3.new(0.6, 6.5, 0.6), Vector3.new(x, 4.5, 2.6), palette.Gold, Enum.Material.SmoothPlastic)
	end
	-- A pair of oversized sneakers on the counter, so it reads from far away.
	for _, x in { -1.6, 1.6 } do
		part("Shoe", Vector3.new(1.6, 1.2, 3.2), Vector3.new(x, 4.6, 0), palette.Gold, Enum.Material.SmoothPlastic)
	end
	local sign =
		part("SignBoard", Vector3.new(9, 3, 0.4), Vector3.new(0, 10.5, 3), palette.Cream, Enum.Material.SmoothPlastic)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 42)
	billboard.StudsOffset = Vector3.new(0, 4.5, 0)
	billboard.MaxDistance = 20
	billboard.LightInfluence = 0
	billboard.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = "속도 신발 상점"
	label.TextColor3 = palette.Ink
	label.TextStrokeColor3 = palette.Cream
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Parent = billboard
	model.PrimaryPart = counter
	model.Parent = park.ParkFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SpeedPrompt"
	prompt.ActionText = "속도 올리기"
	prompt.ObjectText = "속도 신발 상점"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	local function publish(player: Player)
		player:SetAttribute("SpeedLevel", getLevel(player))
	end
	local function onPlayer(player: Player)
		task.spawn(function()
			-- The saved level is loaded before leaderstats appears.
			player:WaitForChild("leaderstats", 30)
			publish(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	prompt.Triggered:Connect(function(player: Player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") or (root.Position - counter.Position).Magnitude > 24 then
			return
		end
		local level = getLevel(player)
		local cost = GameConfig.SpeedLevelCosts[level + 1]
		if cost == nil then
			notify(player, "속도 최대", "더 올릴 수 없어요")
			return
		end
		if not spendCoins(player, cost) then
			notify(
				player,
				string.format("%s이 부족해요", GameConfig.CurrencyDisplayName),
				string.format("속도 %d단계는 %d %s이에요", level + 1, cost, GameConfig.CurrencyDisplayName)
			)
			return
		end
		setLevel(player, level + 1)
		publish(player)
		notify(player, string.format("속도 %d단계", level + 1), "이동 속도가 올랐어요")
	end)
end

return SpeedShopService
