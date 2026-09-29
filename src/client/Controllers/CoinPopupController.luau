--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Small floating "+N 코인" texts where coins were earned (a boarding guest, a picked-up piece of litter),
-- so income is visible in the world instead of filling the centre of the screen with popups.
local CoinPopupController = {}

local RISE_STUDS = 9
local LIFETIME = 1.6

function CoinPopupController.Start()
	local popupEvent = ReplicatedStorage:WaitForChild("ParkParkEvents"):WaitForChild("CoinPopup") :: RemoteEvent

	popupEvent.OnClientEvent:Connect(function(position: unknown, text: unknown)
		if typeof(position) ~= "Vector3" or type(text) ~= "string" then
			return
		end

		-- Client-only anchor under the camera, so nothing here replicates or blocks anyone.
		local anchor = Instance.new("Part")
		anchor.Name = "CoinPopup"
		anchor.Size = Vector3.one
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		local start = position + Vector3.new((math.random() - 0.5) * 4, 0, (math.random() - 0.5) * 4)
		anchor.Position = start
		anchor.Parent = Workspace.CurrentCamera or Workspace

		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(170, 44)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.MaxDistance = 220
		gui.Adornee = anchor
		gui.Parent = anchor

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.Text = text
		label.TextSize = 26
		label.TextColor3 = GameConfig.Palette.Gold
		label.TextStrokeColor3 = GameConfig.Palette.Ink
		label.TextStrokeTransparency = 0.25
		label.Parent = gui

		local info = TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(anchor, info, { Position = start + Vector3.new(0, RISE_STUDS, 0) }):Play()
		TweenService:Create(label, TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(LIFETIME + 0.1, function()
			anchor:Destroy()
		end)
	end)
end

return CoinPopupController
