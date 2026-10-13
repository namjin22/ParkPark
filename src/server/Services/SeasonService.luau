--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))

-- Seasonal events: the current (UTC) date picks a season from GameConfig.Seasons (or the park attribute
-- `ForceSeason` for tests). While one is on, themed decor stands along the main path and plaza, the park attribute
-- `Season` / `SeasonName` is set, income gets `SeasonBonus` (read by IncomeService), and the season's limited
-- cosmetics can be bought in the closet. Decor uses a `Decor<Kind>` template when imported, else a plain stand-in.
local SeasonService = {}

type Notify = (Player, string, string) -> ()
type FindTemplate = (string) -> Model?

local STAND_INS: { [string]: { color: Color3, size: Vector3, shape: Enum.PartType?, lift: number } } = {
	DecorPumpkin = {
		color = Color3.fromRGB(235, 140, 60),
		size = Vector3.new(3, 2.6, 3),
		shape = Enum.PartType.Ball,
		lift = 1.3,
	},
	DecorSpookyLamp = { color = Color3.fromRGB(150, 110, 200), size = Vector3.new(1, 6, 1), shape = nil, lift = 3 },
	DecorSnowman = {
		color = Color3.fromRGB(240, 244, 250),
		size = Vector3.new(3.4, 4.6, 3.4),
		shape = Enum.PartType.Ball,
		lift = 2.3,
	},
	DecorXmasTree = { color = Color3.fromRGB(60, 140, 90), size = Vector3.new(5, 9, 5), shape = nil, lift = 4.5 },
	DecorPaperLantern = {
		color = Color3.fromRGB(226, 90, 80),
		size = Vector3.new(2.4, 3, 2.4),
		shape = Enum.PartType.Ball,
		lift = 5,
	},
	DecorFireworkLauncher = {
		color = Color3.fromRGB(120, 124, 132),
		size = Vector3.new(1.4, 2, 1.4),
		shape = Enum.PartType.Cylinder,
		lift = 1,
	},
}

local function standIn(kind: string): Model
	local info = STAND_INS[kind] or STAND_INS.DecorPumpkin
	local model = Instance.new("Model")
	model.Name = kind
	local piece = Instance.new("Part")
	piece.Name = "Piece"
	piece.Size = info.size
	piece.Position = Vector3.new(0, info.lift, 0)
	piece.Color = info.color
	piece.Material = Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.CanCollide = false
	if info.shape then
		piece.Shape = info.shape
	end
	piece.Parent = model
	model.PrimaryPart = piece
	return model
end

-- The season for a UTC date, or nil.
local function seasonFor(month: number, day: number): any?
	local stamp = month * 100 + day
	for _, season in GameConfig.Seasons do
		local from = season.FromMonth * 100 + season.FromDay
		local to = season.ToMonth * 100 + season.ToDay
		local inside = if from <= to then stamp >= from and stamp <= to else stamp >= from or stamp <= to
		if inside then
			return season
		end
	end
	return nil
end

function SeasonService.Start(park: { ParkFolder: Folder }, notify: Notify, findTemplate: FindTemplate)
	local folder = park.ParkFolder
	local holder = Instance.new("Folder")
	holder.Name = "SeasonDecor"
	holder.Parent = folder
	local current: string? = nil

	local function clear()
		holder:ClearAllChildren()
	end

	local function place(season: any)
		local random = Random.new(season.Seed)
		local kinds: { string } = season.Decor
		-- Along both sides of the main path from the plaza to the carousel, a piece every so often.
		local index = 0
		for z = 92, -80, -14 do
			for _, side in { -1, 1 } do
				index += 1
				local kind = kinds[(index - 1) % #kinds + 1]
				local x = side * (8.5 + random:NextNumber(-0.6, 0.6))
				local template = findTemplate(kind)
				local model = if template then template:Clone() else standIn(kind)
				model.Name = kind
				model:PivotTo(
					CFrame.new(x, 0, z + random:NextNumber(-1.5, 1.5))
						* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
				)
				model.Parent = holder
			end
		end
	end

	local function apply(season: any?)
		local key = if season then season.Key else nil
		if key == current then
			return
		end
		current = key
		clear()
		folder:SetAttribute("Season", key)
		folder:SetAttribute("SeasonName", if season then season.Name else nil)
		folder:SetAttribute("SeasonBonus", if season then season.IncomeBonus else nil)
		if season then
			place(season)
			for _, player in Players:GetPlayers() do
				notify(player, season.Name .. " 시작", season.Detail)
			end
		end
	end

	local function tick()
		local forced = folder:GetAttribute("ForceSeason")
		if type(forced) == "string" and forced ~= "" then
			for _, season in GameConfig.Seasons do
				if season.Key == forced then
					apply(season)
					return
				end
			end
		end
		local now = os.date("!*t")
		apply(seasonFor(now.month, now.day))
	end

	tick()
	folder:GetAttributeChangedSignal("ForceSeason"):Connect(tick)
	task.spawn(function()
		while folder.Parent ~= nil do
			task.wait(300)
			tick()
		end
	end)
	Players.PlayerAdded:Connect(function(player: Player)
		task.delay(10, function()
			local name = folder:GetAttribute("SeasonName")
			if player.Parent and type(name) == "string" then
				notify(player, name, "계절 장식과 한정 꾸미기가 있어요")
			end
		end)
	end)
end

return SeasonService
