--!strict

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Rain on the client: while the park attribute `Weather` is "Rain" a box of raindrops follows the camera and the
-- scene is dimmed a little with a colour-correction effect. Nothing here touches gameplay.
local WeatherController = {}

function WeatherController.Start()
	local park = Workspace:WaitForChild("ParkParkWorld")

	local correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "ParkParkWeather"
	correction.Saturation = 0
	correction.Brightness = 0
	correction.Contrast = 0
	correction.Parent = Lighting

	local emitterPart = Instance.new("Part")
	emitterPart.Name = "ParkParkRain"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(70, 1, 70)
	emitterPart.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Rate = 500
	emitter.Lifetime = NumberRange.new(0.9, 1.1)
	emitter.Speed = NumberRange.new(70, 80)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.SpreadAngle = Vector2.new(4, 4)
	emitter.Size = NumberSequence.new(0.45)
	emitter.Squash = NumberSequence.new(-3)
	emitter.Transparency = NumberSequence.new(0.2)
	emitter.Color = ColorSequence.new(Color3.fromRGB(190, 210, 235))
	emitter.LightEmission = 0.5
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.Parent = emitterPart

	local connection: RBXScriptConnection? = nil
	local function apply()
		local raining = park:GetAttribute("Weather") == "Rain"
		emitter.Enabled = raining
		TweenService:Create(
			correction,
			TweenInfo.new(1.5),
			{ Saturation = if raining then -0.25 else 0, Brightness = if raining then -0.06 else 0 }
		):Play()
		if raining and connection == nil then
			connection = RunService.RenderStepped:Connect(function()
				local camera = Workspace.CurrentCamera
				if camera then
					emitterPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 32, 0))
				end
			end)
		elseif not raining and connection then
			connection:Disconnect()
			connection = nil
		end
	end
	park:GetAttributeChangedSignal("Weather"):Connect(apply)
	apply()
end

return WeatherController
