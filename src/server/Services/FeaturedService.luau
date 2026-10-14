--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Today's recommended ride: once per UTC day one repaired attraction is featured and its income is raised by
-- GameConfig.Featured.Bonus (IncomeService reads the model attribute `Featured`). The pick is a stable hash of the
-- ride key and the day among the rides repaired at that moment, and it is kept for the rest of the day while that
-- ride stays repaired. The park attribute `FeaturedRide` carries the key, a billboard marks the ride, and players
-- get a notice when the day's ride is chosen and shortly after they join.
local FeaturedService = {}

type Notify = (Player, string, string) -> ()

local DAY = 86400

local function score(key: string, day: number): number
	local hash = day * 7919
	for index = 1, #key do
		hash = (hash * 31 + string.byte(key, index)) % 1000003
	end
	return hash
end

function FeaturedService.Start(park: { ParkFolder: Folder }, notify: Notify)
	local folder = park.ParkFolder
	local bonus = GameConfig.Featured.Bonus
	local currentDay = -1
	local currentKey = ""
	local currentModel: Model? = nil
	local billboard: BillboardGui? = nil

	local function displayName(key: string): string
		local config = GameConfig.Rides[key]
		return if config then config.DisplayName else key
	end

	local function rideModels(): { [string]: Model }
		local found: { [string]: Model } = {}
		for _, child in folder:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("IsRepaired") == true then
				local key = child:GetAttribute("RideKey")
				if type(key) == "string" then
					found[key] = child
				end
			end
		end
		return found
	end

	local function clear()
		if currentModel then
			currentModel:SetAttribute("Featured", nil)
		end
		if billboard then
			billboard:Destroy()
			billboard = nil
		end
		currentModel = nil
		currentKey = ""
		folder:SetAttribute("FeaturedRide", "")
	end

	local function mark(key: string, model: Model)
		currentModel = model
		currentKey = key
		model:SetAttribute("Featured", true)
		folder:SetAttribute("FeaturedRide", key)
		local anchor = model:FindFirstChild("RepairConsole", true) or model:FindFirstChild("Console", true)
		if anchor == nil or not anchor:IsA("BasePart") then
			anchor = model:FindFirstChildWhichIsA("BasePart", true)
		end
		if anchor and anchor:IsA("BasePart") then
			local gui = Instance.new("BillboardGui")
			gui.Name = "FeaturedTag"
			gui.Size = UDim2.fromOffset(170, 34)
			gui.StudsOffset = Vector3.new(0, 11, 0)
			gui.MaxDistance = 70
			gui.LightInfluence = 0
			gui.Parent = anchor
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundColor3 = GameConfig.Palette.Cream
			label.BackgroundTransparency = 0.1
			label.Font = Enum.Font.GothamBold
			label.Text = string.format("오늘의 추천 +%d%%", math.floor(bonus * 100 + 0.5))
			label.TextScaled = true
			label.TextColor3 = GameConfig.Palette.Ink
			label.Parent = gui
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = label
			billboard = gui
		end
	end

	local function announce(player: Player)
		if currentKey ~= "" then
			notify(
				player,
				"오늘의 추천 놀이기구",
				string.format("%s · 수입 +%d%%", displayName(currentKey), math.floor(bonus * 100 + 0.5))
			)
		end
	end

	local function update()
		local today = os.time() // DAY
		local models = rideModels()
		-- Keep today's pick while it stays repaired.
		if today == currentDay and currentKey ~= "" and models[currentKey] == currentModel then
			return
		end
		local best: string? = nil
		local bestScore = -1
		for key in models do
			local value = score(key, today)
			if value > bestScore or (value == bestScore and best ~= nil and key < best) then
				best = key
				bestScore = value
			end
		end
		local dayChanged = today ~= currentDay
		clear()
		currentDay = today
		if best then
			mark(best, models[best])
			if dayChanged then
				for _, player in Players:GetPlayers() do
					announce(player)
				end
			end
		end
	end

	Players.PlayerAdded:Connect(function(player: Player)
		task.delay(12, function()
			if player.Parent ~= nil then
				announce(player)
			end
		end)
	end)

	task.spawn(function()
		while folder.Parent ~= nil do
			update()
			task.wait(15)
		end
	end)
end

return FeaturedService
