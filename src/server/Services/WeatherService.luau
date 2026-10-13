--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local ParkLayout =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("ParkLayout"))

-- Weather: while the park is open, every few minutes a rain shower comes (income x RainMultiplier, guests lean
-- towards the indoor rides) and, after most showers, a rainbow stays for a while (income x RainbowMultiplier). The
-- park attributes `Weather` ("Rain", "Rainbow" or ""), `WeatherEnds` (os.time) and `WeatherMultiplier` carry the
-- state: IncomeService and GuestService read them, the client WeatherController draws rain and dims the screen.
-- The rainbow is drawn here, as seven curved beams in the sky behind the plaza. Set `ForceWeather` to
-- "Rain" or "Rainbow" on the park folder to start one at once (tests).
local WeatherService = {}

type Notify = (Player, string, string) -> ()

local BAND_COLORS = {
	Color3.fromRGB(235, 90, 90),
	Color3.fromRGB(240, 150, 80),
	Color3.fromRGB(245, 215, 90),
	Color3.fromRGB(120, 200, 120),
	Color3.fromRGB(100, 170, 230),
	Color3.fromRGB(120, 120, 220),
	Color3.fromRGB(170, 120, 210),
}

local function buildRainbow(parent: Instance): Folder
	local holder = Instance.new("Folder")
	holder.Name = "Rainbow"
	local center = ParkLayout.WeatherRainbowCenter
	local halfWidth = ParkLayout.WeatherRainbowHalfWidth
	for index, color in BAND_COLORS do
		local drop = (index - 1) * 5
		local function endpoint(side: number): Attachment
			local part = Instance.new("Part")
			part.Name = "RainbowEnd"
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.Transparency = 1
			part.Size = Vector3.new(1, 1, 1)
			part.Position = center + Vector3.new(side * (halfWidth - drop * 0.6), -drop * 0.5, 0)
			part.Parent = holder
			local attachment = Instance.new("Attachment")
			-- The curve bends along the attachment's X axis, so turn it to point up.
			attachment.Orientation = Vector3.new(0, 0, 90)
			attachment.Parent = part
			return attachment
		end
		local a0 = endpoint(-1)
		local a1 = endpoint(1)
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.FaceCamera = true
		beam.Segments = 24
		beam.CurveSize0 = ParkLayout.WeatherRainbowHeight
		beam.CurveSize1 = -ParkLayout.WeatherRainbowHeight
		beam.Width0 = 5
		beam.Width1 = 5
		beam.Color = ColorSequence.new(color)
		beam.LightEmission = 0.4
		beam.Transparency = NumberSequence.new(0.25)
		beam.Parent = a0.Parent
	end
	holder.Parent = parent
	return holder
end

function WeatherService.Start(park: { ParkFolder: Folder }, notify: Notify)
	local folder = park.ParkFolder
	local settings = GameConfig.Weather
	local random = Random.new()
	local rainbow: Folder? = nil

	local function announce(title: string, detail: string)
		for _, player in Players:GetPlayers() do
			notify(player, title, detail)
		end
	end

	local function setWeather(name: string, seconds: number, multiplier: number)
		folder:SetAttribute("Weather", name)
		folder:SetAttribute("WeatherEnds", if seconds > 0 then os.time() + seconds else 0)
		folder:SetAttribute("WeatherMultiplier", multiplier)
		if name == "Rainbow" then
			if rainbow == nil then
				rainbow = buildRainbow(folder)
			end
		elseif rainbow then
			rainbow:Destroy()
			rainbow = nil
		end
	end
	setWeather("", 0, 1)

	local function rain()
		setWeather("Rain", settings.RainSeconds, settings.RainMultiplier)
		announce("비가 와요", "수입이 조금 줄고 손님이 실내 시설을 찾아요")
		task.wait(settings.RainSeconds)
		setWeather("", 0, 1)
	end
	local function rainbowOnly()
		setWeather("Rainbow", settings.RainbowSeconds, settings.RainbowMultiplier)
		announce("무지개가 떴어요", "잠시 수입이 늘어요")
		task.wait(settings.RainbowSeconds)
		setWeather("", 0, 1)
	end

	task.spawn(function()
		local nextAt = os.clock() + random:NextNumber(settings.IntervalMin, settings.IntervalMax)
		while folder.Parent ~= nil do
			task.wait(1)
			local forced = folder:GetAttribute("ForceWeather")
			if type(forced) == "string" and forced ~= "" then
				folder:SetAttribute("ForceWeather", "")
				if forced == "Rain" then
					rain()
					if random:NextNumber() < settings.RainbowChance then
						rainbowOnly()
					end
				elseif forced == "Rainbow" then
					rainbowOnly()
				end
			elseif os.clock() >= nextAt and folder:GetAttribute("ParkOpen") == true then
				rain()
				if random:NextNumber() < settings.RainbowChance then
					rainbowOnly()
				end
				nextAt = os.clock() + random:NextNumber(settings.IntervalMin, settings.IntervalMax)
			end
		end
	end)
end

return WeatherService
