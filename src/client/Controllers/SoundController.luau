--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local SoundService = game:GetService("SoundService")

-- Small interface sounds built into Roblox (rbxasset://sounds), so no uploaded audio is needed: a ping when coins
-- come in (higher for bigger amounts), a snap when coins are spent, and a chime for server notices.
local SoundController = {}

local COIN_SOUND = "rbxasset://sounds/electronicpingshort.wav"
local SPEND_SOUND = "rbxasset://sounds/snap.mp3"
local NOTICE_SOUND = "rbxasset://sounds/victory.wav"
local MIN_GAP = 0.12

local function makeSound(name: string, id: string, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end

local function play(sound: Sound, speed: number)
	sound.PlaybackSpeed = speed
	sound:Play()
end

function SoundController.Start()
	local coinSound = makeSound("ParkCoinSound", COIN_SOUND, 0.3)
	local spendSound = makeSound("ParkSpendSound", SPEND_SOUND, 0.4)
	local noticeSound = makeSound("ParkNoticeSound", NOTICE_SOUND, 0.25)

	-- Finishing any prompt hold (gathering, fishing, delivery, buying) gives a short click.
	local clickSound = makeSound("ParkClickSound", "rbxasset://sounds/switch.mp3", 0.35)
	ProximityPromptService.PromptTriggered:Connect(function()
		play(clickSound, 1)
	end)

	local events = ReplicatedStorage:WaitForChild("ParkParkEvents", 30)
	local notice = if events then events:FindFirstChild("Notice") else nil
	if notice and notice:IsA("RemoteEvent") then
		notice.OnClientEvent:Connect(function()
			play(noticeSound, 1)
		end)
	end

	local leaderstats = Players.LocalPlayer:WaitForChild("leaderstats", 60)
	local coins = if leaderstats then leaderstats:WaitForChild("Coins", 30) else nil
	if coins == nil or not coins:IsA("IntValue") then
		return
	end
	local last = coins.Value
	local lastPlayed = 0
	coins.Changed:Connect(function(value: number)
		local delta = value - last
		last = value
		if delta == 0 or os.clock() - lastPlayed < MIN_GAP then
			return
		end
		lastPlayed = os.clock()
		if delta > 0 then
			play(coinSound, 1 + math.min(0.6, math.log10(delta + 1) * 0.12))
		else
			play(spendSound, 1)
		end
	end)
end

return SoundController
