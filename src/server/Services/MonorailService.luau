--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ActiveIncome = require(script.Parent.ActiveIncome)
local MissionService = require(script.Parent.MissionService)
local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- The monorail: an elevated rail above the zone road with one station at the park end and one just inside each
-- open zone's gate. A train shuttles between the open stations (`GameConfig.Monorail`), docking at each for a few
-- seconds; a prompt at the station kiosk seats a player on a free seat while the train is docked there. Riders stay
-- seated until they jump out or the train reaches either end of the line, where everyone is set down at the
-- station kiosk. It is free, stops during a power outage, and only built-in shapes are used for now.
local MonorailService = {}

type Station = { key: string, name: string, z: number, kiosk: BasePart, prompt: ProximityPrompt }

local function newPart(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function MonorailService.Start(
	park: { ParkFolder: Folder },
	awardCoins: (Player, number) -> boolean,
	notify: (Player, string, string) -> (),
	getStamps: (Player) -> { string },
	setStamps: (Player, { string }) -> (),
	grant: (Player, string) -> boolean
)
	local folder = park.ParkFolder
	local settings = GameConfig.Monorail
	local palette = GameConfig.Palette
	local railX = ParkLayout.MonorailX
	local railY = ParkLayout.MonorailY

	local holder = Instance.new("Folder")
	holder.Name = "Monorail"
	holder.Parent = folder

	-- Stations, ordered from the park end northwards; zones appear in ZoneOrder as they open.
	local stations: { Station } = {}
	local known: { [string]: boolean } = {}

	local rail = newPart(holder, "Rail", Vector3.new(2, 1.2, 10), Vector3.new(railX, railY - 0.6, 0), palette.Cream)
	local railSupports = Instance.new("Folder")
	railSupports.Name = "Supports"
	railSupports.Parent = holder

	-- The train: three cars with two seats each, built around the lead car.
	local train = Instance.new("Model")
	train.Name = "MonorailTrain"
	local seats: { Seat } = {}
	local lead: Part? = nil
	for car = 1, settings.Cars do
		local offset = -(car - 1) * 13
		local body = newPart(train, "Car" .. car, Vector3.new(7, 4.4, 12), Vector3.new(0, 2.2, offset), palette.Mint)
		body.CanCollide = false
		if lead == nil then
			lead = body
		end
		newPart(train, "Roof" .. car, Vector3.new(7.6, 0.6, 12.6), Vector3.new(0, 4.7, offset), palette.Coral).CanCollide =
			false
		for index, x in { -1.7, 1.7 } do
			local seat = Instance.new("Seat")
			seat.Name = string.format("Seat%d_%d", car, index)
			seat.Size = Vector3.new(2.4, 0.8, 2.4)
			seat.Position = Vector3.new(x, 1.4, offset)
			seat.Color = palette.Gold
			seat.Anchored = true
			seat.TopSurface = Enum.SurfaceType.Smooth
			seat.BottomSurface = Enum.SurfaceType.Smooth
			seat.Parent = train
			table.insert(seats, seat)
		end
	end
	train.PrimaryPart = lead
	train.Parent = holder

	-- Stamp rally: a player collects a stamp for each station the train docks at while they ride it (and the one they
	-- board at). Each new stamp pays StampMinutes of the park's income; all stamps give the title StampTitle.
	local stamps: { [Player]: { [string]: boolean } } = {}
	local function publishStamps(player: Player)
		local list: { string } = {}
		local mine: { [string]: boolean } = stamps[player] or {}
		for key in mine do
			table.insert(list, key)
		end
		table.sort(list)
		player:SetAttribute("Stamps", table.concat(list, ","))
	end
	local function stampTotal(): number
		return #GameConfig.ZoneOrder + 1
	end
	local function giveStamp(player: Player, station: Station)
		local mine = stamps[player]
		if mine == nil or mine[station.key] then
			return
		end
		mine[station.key] = true
		local list: { string } = {}
		for key in mine do
			table.insert(list, key)
		end
		setStamps(player, list)
		publishStamps(player)
		local reward = ActiveIncome.Value(folder, GameConfig.Monorail.StampMinutes * 60)
		awardCoins(player, reward)
		notify(
			player,
			"정거장 도장",
			string.format(
				"%s · %d/%d · +%d %s",
				station.name,
				#list,
				stampTotal(),
				reward,
				GameConfig.CurrencyDisplayName
			)
		)
		if #list >= stampTotal() then
			grant(player, GameConfig.Monorail.StampTitle)
		end
	end
	local function stampRiders(station: Station)
		for _, seat in seats do
			local occupant = seat.Occupant
			local character = occupant and occupant.Parent
			local player = character and Players:GetPlayerFromCharacter(character)
			if player then
				giveStamp(player, station)
			end
		end
	end

	local function onStampPlayer(player: Player)
		task.spawn(function()
			player:WaitForChild("leaderstats", 30)
			if player.Parent == nil then
				return
			end
			local set: { [string]: boolean } = {}
			for _, key in getStamps(player) do
				set[key] = true
			end
			stamps[player] = set
			publishStamps(player)
		end)
	end
	Players.PlayerAdded:Connect(onStampPlayer)
	for _, player in Players:GetPlayers() do
		onStampPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		stamps[player] = nil
	end)

	local function groundNear(station: Station): Vector3
		return station.kiosk.Position + Vector3.new(-3, 3.5, 0)
	end

	local function addStation(key: string, name: string, z: number)
		local kiosk = Instance.new("Model")
		kiosk.Name = "Station_" .. key
		local base = newPart(kiosk, "Base", Vector3.new(4, 0.4, 4), Vector3.new(railX + 8, 0.2, z), palette.Cream)
		base.CanCollide = false
		newPart(kiosk, "Post", Vector3.new(0.6, 6, 0.6), Vector3.new(railX + 8, 3.2, z), palette.Ink).CanCollide = false
		local sign = newPart(kiosk, "Sign", Vector3.new(5, 1.6, 0.3), Vector3.new(railX + 8, 6.6, z), palette.Cream)
		sign.CanCollide = false
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(160, 36)
		billboard.StudsOffset = Vector3.new(0, 2.4, 0)
		billboard.MaxDistance = 50
		billboard.LightInfluence = 0
		billboard.Parent = sign
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.Text = "모노레일 " .. name
		label.TextScaled = true
		label.TextColor3 = palette.Ink
		label.TextStrokeColor3 = palette.Cream
		label.TextStrokeTransparency = 0.2
		label.Parent = billboard
		kiosk.PrimaryPart = base
		kiosk.Parent = holder

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "탑승"
		prompt.ObjectText = "모노레일"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = base
		local station: Station = { key = key, name = name, z = z, kiosk = base, prompt = prompt }
		table.insert(stations, station)
	end

	-- Which station the train is at (or heading to); remapped by key when a station opens out of order.
	local index = 1
	local target = 1

	local function rebuild()
		-- New zone stations are appended in zone order, which is also northwards.
		local changed = false
		if not known.Park then
			known.Park = true
			addStation("Park", "공원", ParkLayout.MonorailParkZ)
			changed = true
		end
		for _, zone in GameConfig.ZoneOrder do
			local bounds = ParkLayout.ZoneBounds[zone]
			if not known[zone] and bounds and folder:GetAttribute("Zone_" .. zone) == true then
				known[zone] = true
				addStation(zone, GameConfig.ZoneNames[zone] or zone, bounds.BoundaryZ - ParkLayout.MonorailStationInset)
				changed = true
			end
		end
		if not changed then
			return
		end
		local currentStation = stations[index]
		local targetStation = stations[target]
		table.sort(stations, function(a: Station, b: Station)
			return a.z > b.z
		end)
		index = table.find(stations, currentStation) or 1
		target = table.find(stations, targetStation) or index
		-- The rail spans from the park station to the last open one, with a pillar every 140 studs.
		local first = stations[1].z + 16
		local last = stations[#stations].z - 16
		rail.Size = Vector3.new(2, 1.2, first - last)
		rail.Position = Vector3.new(railX, railY - 0.6, (first + last) / 2)
		railSupports:ClearAllChildren()
		local z = first
		while z > last do
			local pillar = newPart(
				railSupports,
				"Pillar",
				Vector3.new(1.6, railY - 1.2, 1.6),
				Vector3.new(railX + 3.2, (railY - 1.2) / 2, z),
				palette.Cream
			)
			pillar.CanCollide = false
			z -= 140
		end
	end
	rebuild()

	-- Train state.
	local position = stations[1].z
	local direction = 1
	local docked = true
	local dockUntil = os.clock() + settings.DockSeconds
	folder:SetAttribute("MonorailAt", stations[1].key)

	local function place()
		train:PivotTo(CFrame.new(railX, railY + 0.2, position))
	end
	place()

	local function setPrompts()
		local anyFree = false
		for _, seat in seats do
			if seat.Occupant == nil then
				anyFree = true
				break
			end
		end
		for i, station in stations do
			station.prompt.Enabled = docked and i == index and #stations >= 2 and anyFree
		end
	end

	local function setDown(station: Station)
		for _, seat in seats do
			local occupant = seat.Occupant
			if occupant then
				local character = occupant.Parent
				occupant.Sit = false
				if character and character:IsA("Model") then
					task.defer(function()
						character:PivotTo(CFrame.new(groundNear(station)))
					end)
				end
			end
		end
	end

	-- One handler for every kiosk prompt: prompts are created as stations open, so connect them here.
	local connected: { [ProximityPrompt]: boolean } = {}
	local function connectPrompts()
		for _, station in stations do
			if not connected[station.prompt] then
				connected[station.prompt] = true
				station.prompt.Triggered:Connect(function(player: Player)
					local character = player.Character
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if humanoid == nil or root == nil or not root:IsA("BasePart") or humanoid.Health <= 0 then
						return
					end
					if not docked or stations[index] ~= station then
						return
					end
					if (root.Position - station.kiosk.Position).Magnitude > 22 or humanoid.SeatPart ~= nil then
						return
					end
					for _, seat in seats do
						if seat.Occupant == nil then
							(character :: Model):PivotTo(seat.CFrame + Vector3.new(0, 3, 0))
							seat:Sit(humanoid)
							MissionService.Report(player, "Monorail")
							giveStamp(player, station)
							break
						end
					end
					setPrompts()
				end)
			end
		end
	end
	connectPrompts()
	setPrompts()

	local lastSeatCheck = 0
	local lastRebuild = 0
	RunService.Heartbeat:Connect(function(dt: number)
		if folder.Parent == nil then
			return
		end
		local now = os.clock()
		if now - lastRebuild > 1 then
			lastRebuild = now
			rebuild()
			connectPrompts()
		end
		local powered = folder:GetAttribute("PowerOut") ~= true
		if docked then
			if now - lastSeatCheck > 0.5 then
				lastSeatCheck = now
				setPrompts()
			end
			if powered and #stations >= 2 and now >= dockUntil then
				if index >= #stations then
					direction = -1
				elseif index <= 1 then
					direction = 1
				end
				target = math.clamp(index + direction, 1, #stations)
				docked = false
				folder:SetAttribute("MonorailAt", "")
				setPrompts()
			end
			return
		end
		if not powered then
			return
		end
		local goal = stations[target].z
		local remaining = position - goal
		local speed = math.clamp(math.abs(remaining) * 1.1, 14, settings.Speed)
		local step = math.min(math.abs(remaining), speed * dt)
		position -= math.sign(remaining) * step
		place()
		if math.abs(position - goal) < 0.05 then
			position = goal
			place()
			index = target
			docked = true
			dockUntil = now + settings.DockSeconds
			folder:SetAttribute("MonorailAt", stations[index].key)
			stampRiders(stations[index])
			if index == 1 or index == #stations then
				setDown(stations[index])
			end
			setPrompts()
		end
	end)

	Players.PlayerRemoving:Connect(function()
		task.defer(setPrompts)
	end)
end

return MonorailService
