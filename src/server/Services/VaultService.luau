--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActiveIncome = require(script.Parent.ActiveIncome)
local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- The coin vault: coins the park earned while the player was away. When a player joins, the time since they were last
-- seen (capped) is turned into VaultEfficiency of the park's current income per minute and added to their vault;
-- holding E at the vault on the plaza pays it out. The vault amount and the last-seen time are saved per player.
-- It is free and small next to playing, so it only softens a long absence.
local VaultService = {}

type AwardCoins = (Player, number) -> boolean
type Notify = (Player, string, string) -> ()
type Popup = (Vector3, string) -> ()
type FindTemplate = (string) -> Model?
type GetVault = (Player) -> (number, number)
type SetVault = (Player, number) -> ()

local function buildGraybox(): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "CoinVault"
	local function part(name: string, size: Vector3, offset: Vector3, color: Color3): Part
		local piece = Instance.new("Part")
		piece.Name = name
		piece.Size = size
		piece.Position = offset
		piece.Color = color
		piece.Material = Enum.Material.Metal
		piece.Anchored = true
		piece.Parent = model
		return piece
	end
	local body = part("Body", Vector3.new(7, 6, 5.5), Vector3.new(0, 3, 0), Color3.fromRGB(96, 104, 112))
	local door = part("Door", Vector3.new(4.4, 4.4, 0.5), Vector3.new(0, 3, 2.9), Color3.fromRGB(224, 190, 90))
	door.Material = Enum.Material.SmoothPlastic
	local wheel = part("Wheel", Vector3.new(1.6, 1.6, 0.3), Vector3.new(0, 3, 3.3), Color3.fromRGB(70, 74, 80))
	wheel.Shape = Enum.PartType.Ball
	model.PrimaryPart = body
	return model, door
end

function VaultService.Start(
	park: { ParkFolder: Folder },
	awardCoins: AwardCoins,
	notify: Notify,
	popup: Popup,
	findTemplate: FindTemplate,
	getVault: GetVault,
	setVault: SetVault
)
	local folder = park.ParkFolder
	local settings = GameConfig.Vault
	local position = ParkLayout.VaultPosition

	local template = findTemplate("CoinVault")
	local model: Model
	local counter: BasePart
	if template then
		model = template:Clone()
		local found = model:FindFirstChild("Counter", true)
		counter = if found and found:IsA("BasePart") then found else model.PrimaryPart :: BasePart
	else
		model, counter = buildGraybox()
	end
	model.Name = "CoinVault"
	-- The front is local +Z; it faces the main path (+X from the west side of the plaza).
	model:PivotTo(CFrame.lookAt(position, position - Vector3.new(1, 0, 0)))
	model.Parent = folder

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(130, 32)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.MaxDistance = 45
	billboard.LightInfluence = 0
	billboard.Parent = counter
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = "금고"
	label.TextScaled = true
	label.TextColor3 = GameConfig.Palette.Ink
	label.TextStrokeColor3 = GameConfig.Palette.Cream
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "코인 꺼내기"
	prompt.ObjectText = "금고"
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	local balances: { [Player]: number } = {}

	local function publish(player: Player)
		player:SetAttribute("VaultCoins", balances[player] or 0)
	end

	local function onPlayer(player: Player)
		task.spawn(function()
			-- The saved state is loaded before leaderstats appears; the park's income is known a few seconds later.
			player:WaitForChild("leaderstats", 30)
			task.wait(8)
			if player.Parent == nil then
				return
			end
			local lastSeen, vault = getVault(player)
			if lastSeen > 0 then
				local away = math.min(os.time() - lastSeen, settings.CapSeconds)
				if away >= settings.MinimumAwaySeconds then
					local perMinute = ActiveIncome.PerMinute(folder)
					vault += math.floor(perMinute / 60 * away * settings.Efficiency + 0.5)
				end
			end
			balances[player] = vault
			setVault(player, vault)
			publish(player)
			if vault > 0 then
				notify(
					player,
					"금고",
					string.format(
						"%d %s이 쌓여 있어요. 광장 금고에서 꺼내세요",
						vault,
						GameConfig.CurrencyDisplayName
					)
				)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		balances[player] = nil
	end)

	prompt.Triggered:Connect(function(player: Player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") or (root.Position - counter.Position).Magnitude > 24 then
			return
		end
		local vault = balances[player]
		if vault == nil then
			return
		end
		if vault <= 0 then
			notify(player, "금고", "꺼낼 코인이 없어요")
			return
		end
		balances[player] = 0
		setVault(player, 0)
		publish(player)
		awardCoins(player, vault)
		popup(counter.Position + Vector3.new(0, 7, 0), string.format("금고 +%d", vault))
	end)
end

return VaultService
