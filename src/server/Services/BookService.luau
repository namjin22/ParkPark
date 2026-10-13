--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActiveIncome = require(script.Parent.ActiveIncome)
local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))

-- The collection book: every gathering area has one kind of pickup (GameConfig.GatherKinds). GatherService calls
-- Record when a player picks one up; a page is full at GameConfig.Book.PageTarget pickups and pays PageMinutes of the
-- park's income once (the count stops at the target, so it can never pay twice). When every page is full the player
-- gets the title GameConfig.Book.TitleId. The server publishes the pages as the player attribute `Book`
-- ("key|label|count|target" entries joined by ";") for the client panel.
local BookService = {}

type AwardCoins = (Player, number) -> boolean
type Notify = (Player, string, string) -> ()
type GetBook = (Player) -> { [string]: number }
type SetBook = (Player, { [string]: number }) -> ()
type Grant = (Player, string) -> boolean

local counts: { [Player]: { [string]: number } } = {}
local record: ((Player, string) -> ())? = nil

function BookService.Record(player: Player, areaKey: string)
	if record then
		record(player, areaKey)
	end
end

function BookService.Start(
	park: { ParkFolder: Folder },
	awardCoins: AwardCoins,
	notify: Notify,
	getBook: GetBook,
	setBook: SetBook,
	grant: Grant
)
	local folder = park.ParkFolder
	local target = GameConfig.Book.PageTarget

	local function publish(player: Player)
		local mine = counts[player]
		if mine == nil then
			return
		end
		local entries = {}
		for _, key in GameConfig.GatherOrder do
			local kind = GameConfig.GatherKinds[key]
			if kind then
				table.insert(entries, string.format("%s|%s|%d|%d", key, kind.Label, mine[key] or 0, target))
			end
		end
		player:SetAttribute("Book", table.concat(entries, ";"))
	end

	local function onPlayer(player: Player)
		task.spawn(function()
			-- The saved state is loaded before leaderstats appears.
			player:WaitForChild("leaderstats", 30)
			if player.Parent == nil then
				return
			end
			local saved = getBook(player)
			local mine: { [string]: number } = {}
			for _, key in GameConfig.GatherOrder do
				mine[key] = math.clamp(math.floor(saved[key] or 0), 0, target)
			end
			counts[player] = mine
			publish(player)
			-- A book that is already complete (title not given yet, for example after a failed grant) gets its title now.
			local complete = true
			for _, key in GameConfig.GatherOrder do
				if (mine[key] or 0) < target then
					complete = false
					break
				end
			end
			if complete then
				grant(player, GameConfig.Book.TitleId)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		counts[player] = nil
	end)

	record = function(player: Player, areaKey: string)
		local mine = counts[player]
		local kind = GameConfig.GatherKinds[areaKey]
		if mine == nil or kind == nil then
			return
		end
		local count = mine[areaKey] or 0
		if count >= target then
			return
		end
		count += 1
		mine[areaKey] = count
		setBook(player, mine)
		publish(player)
		if count < target then
			return
		end
		local amount = ActiveIncome.Value(folder, GameConfig.Book.PageMinutes * 60)
		awardCoins(player, amount)
		notify(
			player,
			"도감 한 쪽 완성",
			string.format("%s을 다 모았어요. +%d %s", kind.Label, amount, GameConfig.CurrencyDisplayName)
		)
		local complete = true
		for _, key in GameConfig.GatherOrder do
			if (mine[key] or 0) < target then
				complete = false
				break
			end
		end
		if complete then
			grant(player, GameConfig.Book.TitleId)
		end
	end
end

return BookService
