--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local EconomyService = {}

local function getTicketsValue(player: Player): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats == nil or not leaderstats:IsA("Folder") then
		return nil
	end

	local tickets = leaderstats:FindFirstChild("Tickets")
	if tickets == nil or not tickets:IsA("IntValue") then
		return nil
	end

	return tickets
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

	local tickets = leaderstats:FindFirstChild("Tickets")
	if tickets ~= nil then
		if not tickets:IsA("IntValue") then
			warn("[ParkPark] Tickets must be an IntValue for " .. player.Name)
		end
		return
	end

	local ticketValue = Instance.new("IntValue")
	ticketValue.Name = "Tickets"
	ticketValue.Value = GameConfig.StartingTickets
	ticketValue.Parent = leaderstats
end

function EconomyService.Initialize()
	Players.PlayerAdded:Connect(EconomyService.SetupPlayer)
	for _, player in Players:GetPlayers() do
		EconomyService.SetupPlayer(player)
	end
end

function EconomyService.AwardTickets(player: Player, amount: number): boolean
	if player.Parent ~= Players or amount ~= amount or amount <= 0 or amount % 1 ~= 0 then
		return false
	end

	local tickets = getTicketsValue(player)
	if tickets == nil then
		return false
	end

	tickets.Value += amount
	return true
end

return EconomyService
