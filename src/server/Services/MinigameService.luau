--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActiveIncome = require(script.Parent.ActiveIncome)
local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Plaza minigame booths (ParkLayout.MinigameBooths, definitions in GameConfig.Minigames). Holding E at a booth plays
-- one round: a set of tries each with a chance to hit, or a single weighted draw. The payout is a number of seconds of
-- the park's income (ActiveIncome), so it scales with progress. A booth has a per-player cooldown, every play has a
-- short global cooldown, and a rolling hourly cap keeps the whole thing a small side income next to the rides.
local MinigameService = {}

type AwardCoins = (Player, number) -> boolean
type Notify = (Player, string, string) -> ()
type Popup = (Vector3, string) -> ()
type FindTemplate = (string) -> Model?

local function buildGraybox(def: any, accent: Color3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = def.Template
	local function part(name: string, size: Vector3, offset: Vector3, color: Color3): Part
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
	local palette = GameConfig.Palette
	local base = part("Base", Vector3.new(8, 0.4, 5.6), Vector3.new(0, 0.2, 0), palette.Cream)
	part("BackWall", Vector3.new(7.6, 6, 0.5), Vector3.new(0, 3.2, -2.3), accent)
	local counter = part("Counter", Vector3.new(7.6, 3, 1.6), Vector3.new(0, 1.9, 1.4), palette.Cream)
	part("Roof", Vector3.new(9, 0.5, 6.4), Vector3.new(0, 6.9, 0), accent)
	for _, x in { -3.9, 3.9 } do
		part("Post", Vector3.new(0.5, 6.5, 0.5), Vector3.new(x, 3.6, 2.6), palette.Gold)
	end
	model.PrimaryPart = base
	return model, counter
end

function MinigameService.Start(
	park: { ParkFolder: Folder },
	awardCoins: AwardCoins,
	notify: Notify,
	popup: Popup,
	findTemplate: FindTemplate
)
	local folder = park.ParkFolder
	local settings = GameConfig.MinigameSettings
	local random = Random.new(41)
	local holder = Instance.new("Folder")
	holder.Name = "Minigames"
	holder.Parent = folder

	local lastBooth: { [Player]: { [string]: number } } = {}
	local lastAny: { [Player]: number } = {}
	local history: { [Player]: { number } } = {}

	local function playsLastHour(player: Player): number
		local now = os.time()
		local list: { number } = history[player] or {}
		local kept: { number } = {}
		for _, stamp in list do
			if now - stamp < settings.WindowSeconds then
				table.insert(kept, stamp)
			end
		end
		history[player] = kept
		return #kept
	end

	local function play(player: Player, def: any, position: Vector3)
		local now = os.clock()
		local boothLast = lastBooth[player]
		if boothLast == nil then
			boothLast = {}
			lastBooth[player] = boothLast
		end
		if now - (boothLast[def.Key] or 0) < def.CooldownSeconds then
			notify(player, def.Name, "조금 뒤에 다시 할 수 있어요")
			return
		end
		if now - (lastAny[player] or 0) < settings.GlobalCooldownSeconds then
			return
		end
		if playsLastHour(player) >= settings.MaxPlaysPerWindow then
			notify(player, def.Name, "잠시 쉬었다가 다시 해 보세요")
			return
		end
		boothLast[def.Key] = now
		lastAny[player] = now
		local stamps = history[player]
		if stamps == nil then
			stamps = {}
			history[player] = stamps
		end
		table.insert(stamps, os.time())

		local seconds = 0
		local summary = ""
		if def.Draw then
			local total = 0
			for _, entry in def.Draw do
				total += entry.Weight
			end
			local roll = random:NextNumber(0, total)
			for _, entry in def.Draw do
				roll -= entry.Weight
				if roll <= 0 then
					seconds = entry.Seconds
					summary = entry.Text
					break
				end
			end
		else
			local hits = 0
			for _ = 1, def.Tries do
				if random:NextNumber() < def.HitChance then
					hits += 1
				end
			end
			seconds = hits * def.SecondsPerHit + def.BaseSeconds
			summary = string.format("%d/%d", hits, def.Tries)
		end
		local amount = if seconds > 0 then ActiveIncome.Value(folder, seconds) else 0
		if amount > 0 then
			awardCoins(player, amount)
		end
		popup(position + Vector3.new(0, 9, 0), if amount > 0 then string.format("%s +%d", summary, amount) else summary)
	end

	for index, spot in ParkLayout.MinigameBooths do
		local def = GameConfig.Minigames[spot.Key]
		if def then
			local template = findTemplate(def.Template)
			local model: Model
			local counter: BasePart
			if template then
				model = template:Clone()
				local found = model:FindFirstChild("Counter", true)
				counter = if found and found:IsA("BasePart") then found else model.PrimaryPart :: BasePart
			else
				model, counter = buildGraybox(def, def.Accent)
			end
			model.Name = def.Template .. index
			-- A booth's front is local +Z, so look away from the direction it should face.
			local position = spot.Position
			model:PivotTo(CFrame.lookAt(position, position - spot.Facing))
			model.Parent = holder

			local billboard = Instance.new("BillboardGui")
			billboard.Size = UDim2.fromOffset(150, 34)
			billboard.StudsOffset = Vector3.new(0, 7, 0)
			billboard.MaxDistance = 45
			billboard.LightInfluence = 0
			billboard.Parent = counter
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBold
			label.Text = def.Name
			label.TextScaled = true
			label.TextColor3 = GameConfig.Palette.Ink
			label.TextStrokeColor3 = GameConfig.Palette.Cream
			label.TextStrokeTransparency = 0.2
			label.Parent = billboard

			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = def.Action
			prompt.ObjectText = def.Name
			prompt.HoldDuration = def.HoldSeconds
			prompt.MaxActivationDistance = 14
			prompt.RequiresLineOfSight = false
			prompt.Parent = counter
			prompt.Triggered:Connect(function(player: Player)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") and (root.Position - counter.Position).Magnitude <= 24 then
					play(player, def, counter.Position)
				end
			end)
		end
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		lastBooth[player] = nil
		lastAny[player] = nil
		history[player] = nil
	end)
end

return MinigameService
