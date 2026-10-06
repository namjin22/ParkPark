--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActiveIncome = require(script.Parent.ActiveIncome)
local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Gathering: a handful of small things lie beside the paths of every open area (a clover in the first park, shells
-- on the beach, pine cones, star pieces...). Holding E picks one up for GameConfig.Active.GatherSeconds of the
-- park's income; it grows back somewhere else on the same road after GatherRespawn seconds.
local GatherService = {}

type AwardCoins = (Player, number) -> boolean
type Popup = (Vector3, string) -> ()

type Area = {
	key: string,
	label: string,
	color: Color3,
	minZ: number,
	maxZ: number,
	x: (Random) -> number,
	open: (Folder) -> boolean,
}

local function areas(): { Area }
	local list: { Area } = {
		{
			key = "Entrance",
			label = "클로버",
			color = Color3.fromRGB(120, 210, 130),
			minZ = -80,
			maxZ = 56,
			x = function(random: Random)
				return (if random:NextNumber() < 0.5 then -1 else 1) * random:NextNumber(17, 23)
			end,
			open = function(folder: Folder)
				return folder:GetAttribute("EntranceCleared") == true
			end,
		},
	}
	local zoneLabels: { [string]: { string | Color3 } } = {
		Water = { "조개껍데기", Color3.fromRGB(255, 190, 170) },
		Kids = { "장난감 블록", Color3.fromRGB(255, 120, 120) },
		Adventure = { "솔방울", Color3.fromRGB(190, 140, 90) },
		Winter = { "눈 결정", Color3.fromRGB(190, 230, 255) },
		Space = { "별 조각", Color3.fromRGB(190, 160, 255) },
		Cove = { "금화", Color3.fromRGB(255, 215, 100) },
		Candy = { "알사탕", Color3.fromRGB(255, 130, 190) },
	}
	for _, zone in GameConfig.ZoneOrder do
		local bounds = ParkLayout.ZoneBounds[zone]
		local style = zoneLabels[zone]
		if bounds and style then
			table.insert(list, {
				key = zone,
				label = style[1] :: string,
				color = style[2] :: Color3,
				minZ = bounds.MinZ + 30,
				maxZ = bounds.BoundaryZ - 30,
				x = function(random: Random)
					return ParkLayout.ZoneRoadX
						+ (if random:NextNumber() < 0.5 then -1 else 1) * random:NextNumber(11, 16)
				end,
				open = function(folder: Folder)
					return folder:GetAttribute("Zone_" .. zone) == true
				end,
			})
		end
	end
	return list
end

function GatherService.Start(park: { ParkFolder: Folder }, awardCoins: AwardCoins, popup: Popup)
	local folder = park.ParkFolder
	local random = Random.new(7)
	local holder = Instance.new("Folder")
	holder.Name = "Gatherables"
	holder.Parent = folder

	-- Rows of branch paths and the first park's crossing paths are kept free.
	local blockedRows: { number } = { -12, 4, 16 }
	for _, z in ParkLayout.ZoneBranchZ do
		table.insert(blockedRows, z)
	end

	local function spawnOne(area: Area)
		for _ = 1, 40 do
			local z = random:NextNumber(area.minZ, area.maxZ)
			local clear = true
			for _, row in blockedRows do
				if math.abs(z - row) < 22 then
					clear = false
					break
				end
			end
			if clear then
				local x = area.x(random)
				local item = Instance.new("Part")
				item.Name = "Gatherable"
				item.Shape = Enum.PartType.Ball
				item.Size = Vector3.new(1.8, 1.8, 1.8)
				item.Color = area.color
				item.Material = Enum.Material.Neon
				item.Anchored = true
				item.CanCollide = false
				item.Position = Vector3.new(x, 1.4, z)
				item.Parent = holder
				local glow = Instance.new("Highlight")
				glow.FillTransparency = 1
				glow.OutlineColor = area.color
				glow.Parent = item
				local tag = Instance.new("BillboardGui")
				tag.Size = UDim2.fromOffset(110, 26)
				tag.StudsOffset = Vector3.new(0, 2.2, 0)
				tag.MaxDistance = 36
				tag.LightInfluence = 0
				tag.Parent = item
				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.GothamBold
				label.Text = area.label
				label.TextScaled = true
				label.TextColor3 = Color3.new(1, 1, 1)
				label.TextStrokeTransparency = 0.3
				label.Parent = tag
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "줍기"
				prompt.ObjectText = area.label
				prompt.HoldDuration = 0.5
				prompt.MaxActivationDistance = 11
				prompt.RequiresLineOfSight = false
				prompt.Parent = item
				prompt.Triggered:Connect(function(player: Player)
					if item.Parent == nil then
						return
					end
					item:Destroy()
					local amount = ActiveIncome.Value(folder, GameConfig.Active.GatherSeconds)
					awardCoins(player, amount)
					popup(Vector3.new(x, 4, z), string.format("%s +%d", area.label, amount))
					task.delay(GameConfig.Active.GatherRespawnSeconds, function()
						if folder.Parent ~= nil then
							spawnOne(area)
						end
					end)
				end)
				return
			end
		end
	end

	-- Areas get their pickups the first time they are seen open.
	local filled: { [string]: boolean } = {}
	task.spawn(function()
		local list = areas()
		while folder.Parent ~= nil do
			for _, area in list do
				if not filled[area.key] and area.open(folder) then
					filled[area.key] = true
					for _ = 1, GameConfig.Active.GatherPerArea do
						spawnOne(area)
					end
				end
			end
			task.wait(3)
		end
	end)
end

return GatherService
