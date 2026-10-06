--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActiveIncome = require(script.Parent.ActiveIncome)
local MissionService = require(script.Parent.MissionService)
local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Deliveries: a desk on the plaza hands out a parcel for one of the repaired attractions; carrying it there
-- (holding E at the ride's sign) pays more the farther away the ride is. One parcel at a time per player; it
-- expires after DeliveryTimeoutSeconds. The player attributes `DeliveryTo` (ride key) and `DeliveryName` show
-- what is being carried.
local DeliveryService = {}

type AwardCoins = (Player, number) -> boolean
type Notify = (Player, string, string) -> ()
type Popup = (Vector3, string) -> ()

function DeliveryService.Start(park: { ParkFolder: Folder }, awardCoins: AwardCoins, notify: Notify, popup: Popup)
	local folder = park.ParkFolder
	local active = GameConfig.Active
	local random = Random.new(23)
	local position = ParkLayout.DeliveryDeskPosition
	local palette = GameConfig.Palette

	local desk = Instance.new("Model")
	desk.Name = "DeliveryDesk"
	local function part(name: string, size: Vector3, offset: Vector3, color: Color3): Part
		local piece = Instance.new("Part")
		piece.Name = name
		piece.Size = size
		piece.Position = position + offset
		piece.Color = color
		piece.Material = Enum.Material.SmoothPlastic
		piece.Anchored = true
		piece.Parent = desk
		return piece
	end
	part("Base", Vector3.new(8, 1, 5), Vector3.new(0, 0.5, 0), palette.Cream)
	local counter = part("Counter", Vector3.new(7, 3, 2.6), Vector3.new(0, 2.5, 0), palette.Mint)
	part("Roof", Vector3.new(9, 0.6, 6), Vector3.new(0, 7.5, 0), palette.Coral)
	for _, x in { -3.7, 3.7 } do
		part("Post", Vector3.new(0.5, 6, 0.5), Vector3.new(x, 4.2, 2.1), palette.Gold)
	end
	for index = 1, 3 do
		part(
			"Parcel" .. index,
			Vector3.new(1.4, 1.2, 1.4),
			Vector3.new(-2 + index * 1.4, 4.6, 0),
			Color3.fromRGB(190, 150, 100)
		)
	end
	local sign = part("Sign", Vector3.new(7, 2, 0.3), Vector3.new(0, 9.2, 2.6), palette.Cream)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 42)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.MaxDistance = 40
	billboard.LightInfluence = 0
	billboard.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = "배달 창구"
	label.TextScaled = true
	label.TextColor3 = palette.Ink
	label.Parent = billboard
	desk.PrimaryPart = counter
	desk.Parent = folder

	local pickup = Instance.new("ProximityPrompt")
	pickup.ActionText = "소포 받기"
	pickup.ObjectText = "배달 창구"
	pickup.HoldDuration = 0.5
	pickup.MaxActivationDistance = 14
	pickup.RequiresLineOfSight = false
	pickup.Parent = counter

	local lastDelivery: { [Player]: number } = {}
	local issuedAt: { [Player]: number } = {}

	-- Every repaired attraction gets a "배달하기" prompt on its console; it is only useful to whoever carries a
	-- parcel for it, but the server checks that on every trigger.
	local function rideModels(): { { key: string, model: Model } }
		local list = {}
		for key, config in GameConfig.Rides do
			local model = folder:FindFirstChild(config.ModelName)
			if model and model:IsA("Model") and model:GetAttribute("IsRepaired") == true then
				table.insert(list, { key = key, model = model })
			end
		end
		return list
	end

	local function distanceScale(model: Model): number
		local far = (model:GetPivot().Position - position).Magnitude
		return math.clamp(1 + far / 600, 1, 4)
	end

	local function attach(key: string, model: Model)
		local found = folder:FindFirstChild(GameConfig.Rides[key].ConsoleName, true)
			or model:FindFirstChild("Console", true)
		local anchor = if found and found:IsA("BasePart") then found else nil
		if anchor == nil then
			return
		end
		local existing = anchor:FindFirstChild("DeliverPrompt")
		if existing then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DeliverPrompt"
		prompt.ActionText = "배달하기"
		prompt.ObjectText = GameConfig.Rides[key].DisplayName
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 22
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.UIOffset = Vector2.new(0, 60)
		prompt.Parent = anchor
		prompt.Triggered:Connect(function(who: Player)
			if who:GetAttribute("DeliveryTo") ~= key then
				return
			end
			local reward = math.floor(ActiveIncome.Value(folder, active.DeliverySeconds) * distanceScale(model) + 0.5)
			who:SetAttribute("DeliveryTo", nil)
			who:SetAttribute("DeliveryName", nil)
			lastDelivery[who] = os.clock()
			awardCoins(who, reward)
			MissionService.Report(who, "Deliver")
			popup(anchor.Position + Vector3.new(0, 6, 0), string.format("배달 완료 +%d", reward))
			notify(
				who,
				"배달 완료",
				string.format(
					"%s에 소포를 전했어요 +%d %s",
					GameConfig.Rides[key].DisplayName,
					reward,
					GameConfig.CurrencyDisplayName
				)
			)
		end)
	end

	pickup.Triggered:Connect(function(player: Player)
		if player:GetAttribute("DeliveryTo") ~= nil then
			notify(
				player,
				"배달 중",
				"받은 소포를 먼저 전해 주세요 (놀이기구 콘솔 근처에서 F)"
			)
			return
		end
		if os.clock() - (lastDelivery[player] or 0) < active.DeliveryCooldownSeconds then
			notify(player, "잠시만요", "새 소포를 준비하는 중이에요")
			return
		end
		local options = rideModels()
		if #options == 0 then
			notify(player, "배달할 곳이 없어요", "놀이기구를 먼저 수리하세요")
			return
		end
		local choice = options[random:NextInteger(1, #options)]
		-- Parcels for the nearest rides come up most often; far ones are the big jobs.
		for _, entry in options do
			attach(entry.key, entry.model)
		end
		player:SetAttribute("DeliveryTo", choice.key)
		player:SetAttribute("DeliveryName", GameConfig.Rides[choice.key].DisplayName)
		issuedAt[player] = os.clock()
		local zone = GameConfig.Rides[choice.key].Zone
		notify(
			player,
			string.format("배달: %s", GameConfig.Rides[choice.key].DisplayName),
			string.format(
				"%s · 콘솔 근처에서 F를 길게 누르세요",
				if zone then GameConfig.ZoneNames[zone] else "공원 입구 구역"
			)
		)
		task.delay(active.DeliveryTimeoutSeconds, function()
			if issuedAt[player] and player:GetAttribute("DeliveryTo") == choice.key then
				player:SetAttribute("DeliveryTo", nil)
				player:SetAttribute("DeliveryName", nil)
				notify(player, "배달 시간 초과", "소포가 반송됐어요")
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastDelivery[player] = nil
		issuedAt[player] = nil
	end)
end

return DeliveryService
