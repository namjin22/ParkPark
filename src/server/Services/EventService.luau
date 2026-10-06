--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Now and then something lively happens in the park: a festival (every fare is higher) or a crowd of visitors
-- (more guests arrive). While one runs, the park folder carries `FareMultiplier` / `CrowdMultiplier` for
-- GuestService, plus `EventName` and `EventEnds` (os.time) for anyone who wants to show it.
local EventService = {}

type Notify = (Player, string, string) -> ()
type AwardCoins = (Player, number) -> boolean

local EVENTS = {
	{ Name = "축제", Detail = "모든 놀이기구 요금이 1.5배", Fare = 1.5, Crowd = 1 },
	{ Name = "방문객 몰려옴", Detail = "손님이 평소보다 많이 찾아와요", Fare = 1, Crowd = 1.6 },
	{ Name = "대축제", Detail = "요금 1.3배에 손님도 북적여요", Fare = 1.3, Crowd = 1.3 },
	{
		Name = "동전 비",
		Detail = "하늘에서 동전이 떨어집니다. 주워 보세요",
		Fare = 1,
		Crowd = 1,
		Special = "CoinRain",
	},
	{
		Name = "보물상자",
		Detail = "공원 어딘가에 보물상자가 있어요",
		Fare = 1,
		Crowd = 1,
		Special = "Chest",
	},
}
local COIN_RAIN_SECONDS = 30
local CHEST_SECONDS = 90
local MAX_RAIN_COINS = 60
local GOLD = Color3.fromRGB(255, 210, 90)

function EventService.Start(park: { ParkFolder: Folder }, notify: Notify, awardCoins: AwardCoins)
	local folder = park.ParkFolder
	folder:SetAttribute("FareMultiplier", 1)
	folder:SetAttribute("CrowdMultiplier", 1)
	local random = Random.new()

	local function broadcast(title: string, detail: string)
		for _, player in Players:GetPlayers() do
			notify(player, title, detail)
		end
	end

	-- Special events pay a share of what the park earns: the summed fares of every repaired attraction.
	local function fareSum(): number
		local total = 0
		for _, child in folder:GetChildren() do
			if child:GetAttribute("IsRepaired") == true then
				total += (child:GetAttribute("Fare") :: number?) or 0
			end
		end
		return total
	end

	local function runCoinRain()
		local value = math.max(5, math.floor(fareSum() * 0.01))
		local alive = 0
		local endsAt = os.clock() + COIN_RAIN_SECONDS
		while os.clock() < endsAt and folder.Parent ~= nil do
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if alive < MAX_RAIN_COINS and root and root:IsA("BasePart") then
					alive += 1
					local coin = Instance.new("Part")
					coin.Name = "RainCoin"
					coin.Shape = Enum.PartType.Cylinder
					coin.Size = Vector3.new(0.5, 2.6, 2.6)
					coin.Color = GOLD
					coin.Material = Enum.Material.Neon
					coin.CFrame = CFrame.new(
						root.Position
							+ Vector3.new(
								random:NextNumber(-34, 34),
								random:NextNumber(35, 50),
								random:NextNumber(-34, 34)
							)
					)
					coin.AssemblyAngularVelocity = Vector3.new(0, 0, random:NextNumber(4, 9))
					coin.Parent = folder
					local taken = false
					coin.Touched:Connect(function(hit: BasePart)
						local toucher = Players:GetPlayerFromCharacter(hit.Parent)
						if taken or toucher == nil then
							return
						end
						taken = true
						alive -= 1
						awardCoins(toucher, value)
						coin:Destroy()
					end)
					task.delay(25, function()
						if not taken then
							taken = true
							alive -= 1
							coin:Destroy()
						end
					end)
				end
			end
			task.wait(0.45)
		end
	end

	-- A chest on the road of a random open zone (or the first park); the first player to open it gets the prize.
	local function spawnChest(): (string, Part)
		local spots: { { name: string, x: number, z: number } } = {
			{ name = "공원 입구", x = random:NextNumber(-7, 7), z = random:NextNumber(-80, 70) },
		}
		for _, zone in GameConfig.ZoneOrder do
			local bounds = ParkLayout.ZoneBounds[zone]
			if bounds and folder:GetAttribute("Zone_" .. zone) == true then
				table.insert(spots, {
					name = GameConfig.ZoneNames[zone],
					x = ParkLayout.ZoneRoadX + random:NextNumber(-7, 7),
					z = random:NextNumber(bounds.MinZ + 20, bounds.BoundaryZ - 20),
				})
			end
		end
		local spot = spots[random:NextInteger(1, #spots)]
		local prize = math.max(50, math.floor(fareSum() * 0.5))

		local chest = Instance.new("Part")
		chest.Name = "TreasureChest"
		chest.Size = Vector3.new(4.5, 3, 3)
		chest.Color = Color3.fromRGB(150, 98, 58)
		chest.Material = Enum.Material.Wood
		chest.Anchored = true
		chest.CFrame = CFrame.new(spot.x, 1.6, spot.z)
		chest.Parent = folder
		local lid = Instance.new("Part")
		lid.Name = "Lid"
		lid.Size = Vector3.new(4.7, 0.9, 3.2)
		lid.Color = GOLD
		lid.Material = Enum.Material.SmoothPlastic
		lid.Anchored = true
		lid.CanCollide = false
		lid.CFrame = chest.CFrame * CFrame.new(0, 1.9, 0)
		lid.Parent = chest
		local glow = Instance.new("Highlight")
		glow.FillColor = GOLD
		glow.FillTransparency = 0.5
		glow.OutlineColor = Color3.fromRGB(255, 244, 190)
		glow.Parent = chest
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(150, 40)
		tag.StudsOffset = Vector3.new(0, 4.5, 0)
		tag.MaxDistance = 600
		tag.AlwaysOnTop = true
		tag.LightInfluence = 0
		tag.Parent = chest
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.Text = "보물상자"
		label.TextScaled = true
		label.TextColor3 = GOLD
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.fromRGB(80, 50, 10)
		label.Parent = tag
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "열기"
		prompt.ObjectText = "보물상자"
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = chest
		local opened = false
		prompt.Triggered:Connect(function(player: Player)
			if opened then
				return
			end
			opened = true
			awardCoins(player, prize)
			broadcast(
				"보물상자를 열었어요",
				string.format(
					"%s님이 +%d %s를 얻었어요",
					player.DisplayName,
					prize,
					GameConfig.CurrencyDisplayName
				)
			)
			chest:Destroy()
		end)
		return spot.name, chest
	end

	task.spawn(function()
		while folder.Parent ~= nil do
			-- Set `ForceEvent` on the park folder to start one right away (for testing).
			local waited = 0
			local target = random:NextNumber(GameConfig.EventMinSeconds, GameConfig.EventMaxSeconds)
			while waited < target and folder:GetAttribute("ForceEvent") ~= true do
				waited += task.wait(1)
			end
			local forced = folder:GetAttribute("ForceEvent") == true
			folder:SetAttribute("ForceEvent", nil)
			-- Only a park that is open and has a few rides running gets events; while it does not (closed, a
			-- blackout), keep checking instead of burning the whole interval.
			local function ready(): boolean
				local operating = 0
				for _, child in folder:GetChildren() do
					if child:IsA("Model") and child:GetAttribute("IsOperating") == true then
						operating += 1
					end
				end
				return folder:GetAttribute("ParkOpen") == true and (forced or operating >= GameConfig.EventMinRides)
			end
			local patience = 0
			while not ready() and patience < 300 do
				patience += task.wait(5)
			end
			if ready() then
				local forcedName = folder:GetAttribute("ForceEventName")
				local event = EVENTS[random:NextInteger(1, #EVENTS)]
				if type(forcedName) == "string" then
					for _, candidate in EVENTS do
						if candidate.Special == forcedName then
							event = candidate
						end
					end
				end
				folder:SetAttribute("FareMultiplier", event.Fare)
				folder:SetAttribute("CrowdMultiplier", event.Crowd)
				folder:SetAttribute("EventName", event.Name)
				folder:SetAttribute("EventEnds", os.time() + GameConfig.EventSeconds)
				local chest: Part? = nil
				if event.Special == "Chest" then
					local zoneName, spawned = spawnChest()
					chest = spawned
					broadcast(event.Name .. " 시작", zoneName .. "에 보물상자가 있어요")
				else
					broadcast(event.Name .. " 시작", event.Detail)
				end
				if event.Special == "CoinRain" then
					runCoinRain()
					task.wait(math.max(0, GameConfig.EventSeconds - COIN_RAIN_SECONDS))
				elseif event.Special == "Chest" then
					task.wait(CHEST_SECONDS)
					if chest and chest.Parent then
						chest:Destroy()
					end
				else
					task.wait(GameConfig.EventSeconds)
				end
				folder:SetAttribute("FareMultiplier", 1)
				folder:SetAttribute("CrowdMultiplier", 1)
				folder:SetAttribute("EventName", nil)
				folder:SetAttribute("EventEnds", nil)
				broadcast(event.Name .. " 끝", "다음 행사를 기다려요")
			end
		end
	end)
end

return EventService
