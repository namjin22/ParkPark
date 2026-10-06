--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- The closet: cosmetics only, never gameplay power. Coins buy walk trails and name titles (GameConfig.Cosmetics);
-- the optional supporter pass (GameConfig.Monetization.PassId, 0 = off) unlocks the items marked PassOnly.
-- Ownership and the equipped items are saved with the player; the server publishes them as player attributes
-- (`Owned` = comma-separated ids, `Trail`, `Title`) for the client panel and applies them to the character.
local CosmeticsService = {}

type Equipped = { Trail: string?, Title: string? }
type GetState = (Player) -> ({ string }, Equipped)
type SetState = (Player, { string }, Equipped) -> ()

local itemsById: { [string]: GameConfig.Cosmetic } = {}
for _, item in GameConfig.Cosmetics do
	itemsById[item.Id] = item
end

local function ownsPass(player: Player): boolean
	local passId = GameConfig.Monetization.PassId
	if passId <= 0 then
		return false
	end
	local ok, owned = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	return ok and owned == true
end

function CosmeticsService.Start(
	spendCoins: (Player, number) -> boolean,
	notify: (Player, string, string) -> (),
	getState: GetState,
	setState: SetState
)
	local events = ReplicatedStorage:WaitForChild("ParkParkEvents")
	local remote = events:FindFirstChild("Closet")
	if remote == nil then
		remote = Instance.new("RemoteEvent")
		remote.Name = "Closet"
		remote.Parent = events
	end

	local owned: { [Player]: { [string]: boolean } } = {}
	local equipped: { [Player]: Equipped } = {}
	local passOwner: { [Player]: boolean } = {}

	local function has(player: Player, id: string): boolean
		local item = itemsById[id]
		if item == nil then
			return false
		end
		if item.PassOnly then
			return passOwner[player] == true
		end
		return owned[player] ~= nil and owned[player][id] == true
	end

	local function ownedList(player: Player): { string }
		local list = {}
		local set = owned[player]
		if set then
			for id in set do
				table.insert(list, id)
			end
		end
		table.sort(list)
		return list
	end

	local function publish(player: Player)
		local ids = ownedList(player)
		if passOwner[player] then
			for _, item in GameConfig.Cosmetics do
				if item.PassOnly then
					table.insert(ids, item.Id)
				end
			end
		end
		player:SetAttribute("Owned", table.concat(ids, ","))
		local state: Equipped = equipped[player] or ({} :: Equipped)
		player:SetAttribute("Trail", state.Trail or "")
		player:SetAttribute("Title", state.Title or "")
	end

	local function applyToCharacter(player: Player, character: Model)
		for _, name in { "ParkTrail", "ParkTitle", "ParkTrailA", "ParkTrailB" } do
			local old = character:FindFirstChild(name, true)
			if old then
				old:Destroy()
			end
		end
		local state: Equipped = equipped[player] or ({} :: Equipped)
		local root = character:FindFirstChild("HumanoidRootPart")
		local head = character:FindFirstChild("Head")
		local trailItem = if state.Trail then itemsById[state.Trail] else nil
		if trailItem and root and root:IsA("BasePart") then
			local a = Instance.new("Attachment")
			a.Name = "ParkTrailA"
			a.Position = Vector3.new(0, 0.8, 0)
			a.Parent = root
			local b = Instance.new("Attachment")
			b.Name = "ParkTrailB"
			b.Position = Vector3.new(0, -1.6, 0)
			b.Parent = root
			local trail = Instance.new("Trail")
			trail.Name = "ParkTrail"
			trail.Attachment0 = a
			trail.Attachment1 = b
			trail.Lifetime = 0.9
			trail.LightEmission = 0.7
			trail.FaceCamera = true
			trail.Transparency = NumberSequence.new(0.1, 1)
			if trailItem.Rainbow then
				trail.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 110, 110)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 100)),
					ColorSequenceKeypoint.new(0.66, Color3.fromRGB(110, 220, 170)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 150, 255)),
				})
			else
				trail.Color = ColorSequence.new(trailItem.Color or Color3.new(1, 1, 1))
			end
			trail.Parent = root
		end
		local titleItem = if state.Title then itemsById[state.Title] else nil
		if titleItem and head and head:IsA("BasePart") then
			local tag = Instance.new("BillboardGui")
			tag.Name = "ParkTitle"
			tag.Size = UDim2.fromOffset(150, 28)
			tag.StudsOffset = Vector3.new(0, 2.6, 0)
			tag.MaxDistance = 80
			tag.LightInfluence = 0
			tag.Parent = head
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBlack
			label.Text = titleItem.Text or titleItem.Name
			label.TextScaled = true
			label.TextColor3 = titleItem.Color or Color3.fromRGB(255, 215, 122)
			label.TextStrokeTransparency = 0
			label.TextStrokeColor3 = Color3.fromRGB(50, 40, 30)
			label.Parent = tag
		end
	end

	local function persist(player: Player)
		setState(player, ownedList(player), equipped[player] or ({} :: Equipped))
	end

	local function onPlayer(player: Player)
		task.spawn(function()
			-- The saved state is loaded before leaderstats appears.
			player:WaitForChild("leaderstats", 30)
			local ids, state = getState(player)
			owned[player] = {}
			for _, id in ids do
				if itemsById[id] and not itemsById[id].PassOnly then
					owned[player][id] = true
				end
			end
			passOwner[player] = ownsPass(player)
			local clean: Equipped = {}
			if state.Trail and has(player, state.Trail) then
				clean.Trail = state.Trail
			end
			if state.Title and has(player, state.Title) then
				clean.Title = state.Title
			end
			equipped[player] = clean
			publish(player)
			if player.Character then
				applyToCharacter(player, player.Character)
			end
		end)
		player.CharacterAdded:Connect(function(character: Model)
			if equipped[player] then
				task.defer(applyToCharacter, player, character)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		owned[player] = nil
		equipped[player] = nil
		passOwner[player] = nil
	end)

	local lastAction: { [Player]: number } = {}
	(remote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, action: unknown, id: unknown)
		if type(action) ~= "string" or type(id) ~= "string" or equipped[player] == nil then
			return
		end
		local now = os.clock()
		if now - (lastAction[player] or 0) < 0.3 then
			return
		end
		lastAction[player] = now
		local item = itemsById[id]
		if item == nil then
			return
		end
		local state = equipped[player]
		local slot = if item.Kind == "Trail" then "Trail" else "Title"
		if action == "Buy" then
			if item.PassOnly or has(player, id) then
				return
			end
			if not spendCoins(player, item.Cost) then
				notify(
					player,
					"코인이 부족해요",
					string.format("%d %s이 필요해요", item.Cost, GameConfig.CurrencyDisplayName)
				)
				return
			end
			owned[player][id] = true
			state[slot] = id
			notify(player, item.Name, "구입해서 바로 착용했어요")
		elseif action == "Equip" then
			if not has(player, id) then
				return
			end
			state[slot] = id
		elseif action == "Unequip" then
			if state[slot] == id then
				state[slot] = nil
			end
		else
			return
		end
		publish(player)
		persist(player)
		if player.Character then
			applyToCharacter(player, player.Character)
		end
	end)
end

return CosmeticsService
