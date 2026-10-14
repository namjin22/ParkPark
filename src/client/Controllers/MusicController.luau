--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local UITheme = require(Config:WaitForChild("UITheme"))

-- Soft background music (a playlist that loops) and a quiet crowd loop, with a small "음악" button that turns
-- both off for the session. A track that cannot load is skipped, and with no playable track nothing happens.
local MusicController = {}

function MusicController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local settings = GameConfig.Audio
	local group = Instance.new("SoundGroup")
	group.Name = "ParkParkMusic"
	group.Volume = 1
	group.Parent = SoundService

	local ambience = Instance.new("Sound")
	ambience.Name = "ParkAmbience"
	ambience.SoundId = "rbxassetid://" .. settings.Ambience
	ambience.Looped = true
	ambience.Volume = settings.AmbienceVolume
	ambience.SoundGroup = group
	ambience.Parent = group

	local tracks: { Sound } = {}
	for index, id in settings.Playlist do
		local sound = Instance.new("Sound")
		sound.Name = "Track" .. index
		sound.SoundId = "rbxassetid://" .. id
		sound.Volume = settings.MusicVolume
		sound.SoundGroup = group
		sound.Parent = group
		table.insert(tracks, sound)
	end

	local enabled = true
	local current = 0
	local function playNext()
		if not enabled or #tracks == 0 then
			return
		end
		for _ = 1, #tracks do
			current = current % #tracks + 1
			local sound = tracks[current]
			sound:Play()
			-- A track that has not started after a while did not load: try the next one.
			local waited = 0
			while waited < 6 and enabled and not sound.IsPlaying do
				waited += task.wait(0.5)
			end
			if sound.IsPlaying then
				sound.Ended:Wait()
				return playNext()
			end
			sound:Stop()
		end
	end

	local function setEnabled(value: boolean)
		enabled = value
		group.Volume = if value then 1 else 0
		if value then
			ambience:Play()
			local playing = false
			for _, sound in tracks do
				playing = playing or sound.IsPlaying
			end
			if not playing then
				task.spawn(playNext)
			end
		else
			ambience:Pause()
			for _, sound in tracks do
				sound:Pause()
			end
		end
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ParkParkMusic"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 12
	screenGui.Parent = playerGui
	local toggle = UITheme.MenuButton("음악", screenGui)

	local function updateLayout()
		local camera = Workspace.CurrentCamera
		local compactPortrait = camera ~= nil and UITheme.IsPortrait(camera.ViewportSize)
		toggle.AnchorPoint, toggle.Position = UITheme.MenuSlot(6, compactPortrait)
	end
	local function bindCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
		end
		updateLayout()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()

	toggle.Activated:Connect(function()
		setEnabled(not enabled)
		toggle.TextTransparency = if enabled then 0 else 0.5
	end)

	ambience:Play()
	task.spawn(playNext)
end

return MusicController
