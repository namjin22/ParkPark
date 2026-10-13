--!strict

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ParkAccess = require(script.Parent.ParkAccess)

-- Roblox analytics for the Creator Dashboard (retention comes for free; this adds what a park game needs):
--   * Onboarding funnel for the park's owner: joined, entrance cleaned, carousel repaired, park opened, a third
--     attraction repaired, the first zone opened.
--   * Economy events: coins earned and spent, summed per player and sent once a minute (the income runs every
--     second, so single events would be far too many).
--   * Custom events: each zone opened, and the number of attractions repaired at 5-attraction steps.
-- Every call goes through pcall (the API is not available in every context) and does nothing in Studio.
local AnalyticsHub = {}

type Totals = { source: number, sink: number, balance: number }

local FLUSH_SECONDS = 60
local STEPS = {
	{ attribute = "EntranceCleared", name = "EntranceCleaned" },
	{ attribute = "ParkOpen", name = "ParkOpened" },
}

local totals: { [Player]: Totals } = {}
local enabled = not RunService:IsStudio()

local function safe(call: () -> ())
	if not enabled then
		return
	end
	local ok, err = (pcall :: any)(call)
	if not ok then
		warn("[ParkPark] Analytics call failed: " .. tostring(err))
	end
end

-- Called by EconomyService after a coin change: kind is "Source" or "Sink".
function AnalyticsHub.Economy(player: Player, kind: string, amount: number, balance: number)
	local entry = totals[player]
	if entry == nil then
		entry = { source = 0, sink = 0, balance = balance }
		totals[player] = entry
	end
	if kind == "Source" then
		entry.source += amount
	else
		entry.sink += amount
	end
	entry.balance = balance
end

local function flush(player: Player)
	local entry = totals[player]
	if entry == nil then
		return
	end
	local source, sink, balance = entry.source, entry.sink, entry.balance
	entry.source, entry.sink = 0, 0
	local analytics = AnalyticsService :: any
	if source > 0 then
		safe(function()
			analytics:LogEconomyEvent(
				player,
				Enum.AnalyticsEconomyFlowType.Source,
				"Coins",
				math.floor(balance),
				math.floor(source),
				Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
				"Income"
			)
		end)
	end
	if sink > 0 then
		safe(function()
			analytics:LogEconomyEvent(
				player,
				Enum.AnalyticsEconomyFlowType.Sink,
				"Coins",
				math.floor(balance),
				math.floor(sink),
				Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
				"Purchase"
			)
		end)
	end
end

function AnalyticsHub.Start(park: { ParkFolder: Folder })
	local folder = park.ParkFolder
	local analytics = AnalyticsService :: any
	local stepOf: { [string]: number } = { Joined = 1 }
	for index, step in STEPS do
		stepOf[step.name] = index + 1
	end
	stepOf.ThirdRide = #STEPS + 2
	stepOf.FirstZone = #STEPS + 3
	local sent: { [Player]: { [string]: boolean } } = {}

	local function funnel(player: Player, name: string)
		local done = sent[player]
		if done == nil then
			done = {}
			sent[player] = done
		end
		if done[name] then
			return
		end
		done[name] = true
		safe(function()
			analytics:LogOnboardingFunnelStepEvent(player, stepOf[name], name)
		end)
	end

	local function owner(): Player?
		return ParkAccess.GetOwner() or Players:GetPlayers()[1]
	end

	Players.PlayerAdded:Connect(function(player: Player)
		funnel(player, "Joined")
	end)
	for _, player in Players:GetPlayers() do
		funnel(player, "Joined")
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		flush(player)
		totals[player] = nil
		sent[player] = nil
	end)

	for _, step in STEPS do
		folder:GetAttributeChangedSignal(step.attribute):Connect(function()
			local who = owner()
			if who and folder:GetAttribute(step.attribute) == true then
				funnel(who, step.name)
			end
		end)
	end

	local reportedRepairs = 0
	local reportedZones: { [string]: boolean } = {}
	task.spawn(function()
		while folder.Parent ~= nil do
			task.wait(FLUSH_SECONDS)
			for _, player in Players:GetPlayers() do
				flush(player)
			end
			local who = owner()
			if who == nil then
				continue
			end
			local repaired = 0
			for _, child in folder:GetChildren() do
				if child:IsA("Model") and child:GetAttribute("IsRepaired") == true then
					repaired += 1
				end
			end
			if repaired >= 3 then
				funnel(who, "ThirdRide")
			end
			local bucket = repaired - repaired % 5
			if bucket > reportedRepairs then
				reportedRepairs = bucket
				safe(function()
					analytics:LogCustomEvent(who, "RidesRepaired", bucket)
				end)
			end
			for attribute, value in folder:GetAttributes() do
				if string.sub(attribute, 1, 5) == "Zone_" and value == true and not reportedZones[attribute] then
					reportedZones[attribute] = true
					funnel(who, "FirstZone")
					safe(function()
						analytics:LogCustomEvent(
							who,
							"ZoneOpened",
							1,
							{ [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = string.sub(attribute, 6) }
						)
					end)
				end
			end
		end
	end)
end

return AnalyticsHub
