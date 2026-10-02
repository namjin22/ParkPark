--!strict

local Workspace = game:GetService("Workspace")

-- Signs are readable at two scales: the SurfaceGui on the board (full detail) when the camera is close, and the
-- screen-space `FarLabel` BillboardGui (name and price, crisp at any distance) when it is far. This switches
-- between them by camera distance, with a little hysteresis so a sign at the threshold does not flicker.
local SignLODController = {}

local NEAR = 30
local FAR = 38
local INTERVAL = 0.3

type Sign = { board: BasePart, far: BillboardGui, near: { SurfaceGui }, isNear: boolean }

function SignLODController.Start()
	local park = Workspace:WaitForChild("ParkParkWorld")
	local signs: { [BasePart]: Sign } = {}

	local function register(board: Instance)
		if not board:IsA("BasePart") or signs[board] then
			return
		end
		local far = board:FindFirstChild("FarLabel")
		if far == nil or not far:IsA("BillboardGui") then
			return
		end
		local near: { SurfaceGui } = {}
		for _, child in board:GetChildren() do
			if child:IsA("SurfaceGui") then
				table.insert(near, child)
			end
		end
		signs[board] = { board = board, far = far, near = near, isNear = true }
	end

	for _, descendant in park:GetDescendants() do
		if descendant.Name == "SignBoard" or descendant.Name == "ZoneSign" then
			register(descendant)
		end
	end
	park.DescendantAdded:Connect(function(descendant: Instance)
		if descendant.Name == "SignBoard" or descendant.Name == "ZoneSign" then
			task.defer(register, descendant)
		end
	end)

	while true do
		local camera = Workspace.CurrentCamera
		if camera then
			local position = camera.CFrame.Position
			for board, sign in signs do
				if board.Parent == nil then
					signs[board] = nil
					continue
				end
				local distance = (board.Position - position).Magnitude
				local isNear = if sign.isNear then distance < FAR else distance < NEAR
				sign.isNear = isNear
				for _, gui in sign.near do
					gui.Enabled = isNear
				end
				sign.far.Enabled = not isNear
			end
		end
		task.wait(INTERVAL)
	end
end

return SignLODController
