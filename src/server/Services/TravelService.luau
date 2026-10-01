--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- The park spans more than a thousand studs once the outer zones are open, so players get a quicker stride and
-- a travel menu: the client sends a destination ("Entrance" or an opened zone's key) and the server teleports
-- the player there after checking that the zone really is open (`Zone_<key>` on the park folder).
local TravelService = {}

local COOLDOWN_SECONDS = 1.5

function TravelService.Start(park: { ParkFolder: Folder })
	local folder = park.ParkFolder
	local events = ReplicatedStorage:WaitForChild("ParkParkEvents")
	local event = events:FindFirstChild("Travel")
	if event == nil then
		event = Instance.new("RemoteEvent")
		event.Name = "Travel"
		event.Parent = events
	end
	local travel = event :: RemoteEvent

	local function configureCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.WalkSpeed = GameConfig.PlayerWalkSpeed
		end
	end
	local function onPlayer(player: Player)
		if player.Character then
			task.spawn(configureCharacter, player.Character)
		end
		player.CharacterAdded:Connect(configureCharacter)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	local lastTravel: { [Player]: number } = {}
	travel.OnServerEvent:Connect(function(player: Player, destination: unknown)
		if type(destination) ~= "string" then
			return
		end
		local now = os.clock()
		if now - (lastTravel[player] or 0) < COOLDOWN_SECONDS then
			return
		end

		local target: Vector3? = nil
		if destination == "Entrance" then
			target = Vector3.new(0, 5, ParkLayout.SpawnZ - 8)
		else
			local bounds = ParkLayout.ZoneBounds[destination]
			if bounds and folder:GetAttribute("Zone_" .. destination) == true then
				-- Just inside the gate, on the zone road.
				target = Vector3.new(ParkLayout.ZoneRoadX, 5, bounds.BoundaryZ - 18)
			end
		end
		local character = player.Character
		if target == nil or character == nil then
			return
		end
		lastTravel[player] = now
		character:PivotTo(CFrame.new(target))
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastTravel[player] = nil
	end)
end

return TravelService
