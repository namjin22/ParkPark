--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local EconomyService = {}

-- Set by PersistenceService: returns a saved balance (it may yield while loading) or nil for the default.
local startingCoinsProvider: ((Player) -> number?)? = nil

function EconomyService.SetStartingCoinsProvider(provider: (Player) -> number?)
	startingCoinsProvider = provider
end

local function isValidAmount(amount: number): boolean
	return amount == amount and amount > 0 and amount % 1 == 0
end

local function getCoinsValue(player: Player): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats == nil or not leaderstats:IsA("Folder") then
		return nil
	end

	local coins = leaderstats:FindFirstChild("Coins")
	if coins == nil or not coins:IsA("IntValue") then
		return nil
	end

	return coins
end

function EconomyService.SetupPlayer(player: Player)
	local existingLeaderstats = player:FindFirstChild("leaderstats")
	local leaderstats: Folder
	if existingLeaderstats == nil then
		local newLeaderstats = Instance.new("Folder")
		newLeaderstats.Name = "leaderstats"
		newLeaderstats.Parent = player
		leaderstats = newLeaderstats
	elseif existingLeaderstats:IsA("Folder") then
		leaderstats = existingLeaderstats
	else
		warn("[ParkPark] Could not initialize leaderstats for " .. player.Name)
		return
	end

	local coins = leaderstats:FindFirstChild("Coins")
	if coins ~= nil then
		if not coins:IsA("IntValue") then
			warn("[ParkPark] Coins must be an IntValue for " .. player.Name)
		end
		return
	end

	local coinValue = Instance.new("IntValue")
	coinValue.Name = "Coins"
	coinValue.Value = GameConfig.StartingCoins
	-- The balance is set before the value is parented, so the HUD never shows a jump for a loaded save.
	if startingCoinsProvider then
		local saved = startingCoinsProvider(player)
		if saved ~= nil then
			coinValue.Value = saved
		end
	end
	if player.Parent ~= Players then
		return
	end
	coinValue.Parent = leaderstats
end

function EconomyService.Initialize()
	-- Loading a save can yield, so each player is set up on their own thread.
	Players.PlayerAdded:Connect(function(player: Player)
		EconomyService.SetupPlayer(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(EconomyService.SetupPlayer, player)
	end
end

function EconomyService.GetCoins(player: Player): number
	local coins = getCoinsValue(player)
	return if coins then coins.Value else 0
end

function EconomyService.AwardCoins(player: Player, amount: number): boolean
	if player.Parent ~= Players or not isValidAmount(amount) then
		return false
	end

	local coins = getCoinsValue(player)
	if coins == nil then
		return false
	end

	coins.Value += amount
	return true
end

-- Deducts only when the player can afford the whole amount.
function EconomyService.SpendCoins(player: Player, amount: number): boolean
	if player.Parent ~= Players or not isValidAmount(amount) then
		return false
	end

	local coins = getCoinsValue(player)
	if coins == nil or coins.Value < amount then
		return false
	end

	coins.Value -= amount
	return true
end

return EconomyService
