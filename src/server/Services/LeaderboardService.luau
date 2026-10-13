--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- A plaza board with the ten most valuable parks. A park's value is the summed unlock and repair costs of its
-- repaired attractions plus the zone gates it has opened; the park's owner (the host) reports it to an
-- OrderedDataStore every few minutes, and the board shows the top of that list. It only runs against the real
-- DataStore (the in-memory test mode and Studio without API access skip it).
local LeaderboardService = {}

local STORE_NAME = "ParkParkTopParks"
local STORE_SCOPE = "v1"
local PUBLISH_SECONDS = 300
local REFRESH_SECONDS = 150
local ROWS = 10

local function parkValue(folder: Folder): number
	local total = 0
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("IsRepaired") == true then
			local key = child:GetAttribute("RideKey")
			local config = if type(key) == "string" then GameConfig.Rides[key] else nil
			if config then
				total += config.UnlockCost + config.RepairCost
			end
		end
	end
	for zone, cost in GameConfig.ZoneCosts do
		if folder:GetAttribute("Zone_" .. zone) == true then
			total += cost
		end
	end
	return total
end

local function buildBoard(parent: Instance): TextLabel
	local model = Instance.new("Model")
	model.Name = "TopParksBoard"
	local position = ParkLayout.LeaderboardPosition
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
	local palette = GameConfig.Palette
	for _, x in { -5.2, 5.2 } do
		part("Post", Vector3.new(0.7, 9, 0.7), Vector3.new(x, 4.5, 0), palette.Ink)
	end
	local board = part("Board", Vector3.new(12, 7.5, 0.5), Vector3.new(0, 6.2, 0), palette.Cream)
	model.PrimaryPart = board
	model:PivotTo(CFrame.lookAt(position + Vector3.new(0, 0, 0), position + Vector3.new(0, 0, 10)))
	model.Parent = parent

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextColor3 = palette.Ink
	label.TextSize = 34
	label.Text = "공원 순위\n불러오는 중"
	label.Parent = gui
	return label
end

function LeaderboardService.Start(park: { ParkFolder: Folder }, getHost: () -> Player?, isRealStore: () -> boolean)
	local folder = park.ParkFolder
	local label = buildBoard(folder)
	local names: { [number]: string } = {}

	local function nameOf(userId: number): string
		local cached = names[userId]
		if cached then
			return cached
		end
		local ok, result = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		local name = if ok and type(result) == "string" then result else ("#" .. userId)
		names[userId] = name
		return name
	end

	local function store(): OrderedDataStore?
		if not isRealStore() then
			return nil
		end
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore(STORE_NAME, STORE_SCOPE)
		end)
		return if ok then result else nil
	end

	task.spawn(function()
		while folder.Parent ~= nil do
			task.wait(PUBLISH_SECONDS)
			local ordered = store()
			local host = getHost()
			if ordered and host and host:IsDescendantOf(Players) then
				local value = parkValue(folder)
				if value > 0 then
					pcall(function()
						ordered:SetAsync(tostring(host.UserId), value)
					end)
				end
			end
		end
	end)

	task.spawn(function()
		while folder.Parent ~= nil do
			local ordered = store()
			if ordered then
				local ok, pages = pcall(function()
					return ordered:GetSortedAsync(false, ROWS)
				end)
				if ok then
					local lines = { "공원 순위 (공원 가치)" }
					local rank = 0
					for _, entry in pages:GetCurrentPage() do
						rank += 1
						local userId = tonumber(entry.key)
						if userId then
							table.insert(
								lines,
								string.format("%d. %s  %s", rank, nameOf(userId), tostring(entry.value))
							)
						end
					end
					if rank == 0 then
						table.insert(lines, "아직 기록이 없어요")
					end
					label.Text = table.concat(lines, "\n")
				end
			else
				label.Text = "공원 순위\n(저장소에 연결되면 보여요)"
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return LeaderboardService
