--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Keeps the interface small on small screens. Every ParkPark ScreenGui gets a UIScale (a little smaller on phones),
-- and every floating world label (BillboardGui, from the server or the client) is shrunk once when it appears:
-- its box and the offset parts of its contents' positions and sizes, plus fixed text sizes. Scale parts are left
-- alone because they follow the shrunken box.
local UIScaleController = {}

local PHONE_SIDE = 500 -- shortest viewport side below which the screen counts as a phone
local SCREEN_SCALE_PHONE = 0.9
local LABEL_SCALE = 0.8
local LABEL_SCALE_PHONE = 0.72

local function shortestSide(): number
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return 1000
	end
	return math.min(camera.ViewportSize.X, camera.ViewportSize.Y)
end

local function scaled(value: UDim2, factor: number): UDim2
	return UDim2.new(value.X.Scale, value.X.Offset * factor, value.Y.Scale, value.Y.Offset * factor)
end

function UIScaleController.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Screen UI ------------------------------------------------------------------------------------------------
	local screenScales: { UIScale } = {}
	local function screenFactor(): number
		return if shortestSide() < PHONE_SIDE then SCREEN_SCALE_PHONE else 1
	end
	local function addScreenScale(gui: Instance)
		if not gui:IsA("ScreenGui") or string.sub(gui.Name, 1, 8) ~= "ParkPark" or gui.Name == "ParkParkLoading" then
			return
		end
		if gui:FindFirstChild("ParkParkScreenScale") then
			return
		end
		local scale = Instance.new("UIScale")
		scale.Name = "ParkParkScreenScale"
		scale.Scale = screenFactor()
		scale.Parent = gui
		table.insert(screenScales, scale)
	end
	local function refreshScreenScales()
		local factor = screenFactor()
		for index = #screenScales, 1, -1 do
			local scale = screenScales[index]
			if scale.Parent == nil then
				table.remove(screenScales, index)
			else
				scale.Scale = factor
			end
		end
	end

	-- World labels ---------------------------------------------------------------------------------------------
	-- Fixed for the session: shrinking is applied once per label, so the factor must not change afterwards.
	local labelFactor = if shortestSide() < PHONE_SIDE then LABEL_SCALE_PHONE else LABEL_SCALE
	local done: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

	local function shrinkPart(item: Instance)
		if done[item] then
			return
		end
		done[item] = true
		if item:IsA("GuiObject") then
			item.Position = scaled(item.Position, labelFactor)
			item.Size = scaled(item.Size, labelFactor)
			if item:IsA("TextLabel") or item:IsA("TextButton") then
				local text = item :: any
				if not text.TextScaled then
					text.TextSize = math.max(8, math.floor(text.TextSize * labelFactor + 0.5))
				end
			end
		elseif item:IsA("UIListLayout") then
			item.Padding = UDim.new(item.Padding.Scale, item.Padding.Offset * labelFactor)
		elseif item:IsA("UIPadding") then
			item.PaddingTop = UDim.new(item.PaddingTop.Scale, item.PaddingTop.Offset * labelFactor)
			item.PaddingBottom = UDim.new(item.PaddingBottom.Scale, item.PaddingBottom.Offset * labelFactor)
			item.PaddingLeft = UDim.new(item.PaddingLeft.Scale, item.PaddingLeft.Offset * labelFactor)
			item.PaddingRight = UDim.new(item.PaddingRight.Scale, item.PaddingRight.Offset * labelFactor)
		end
	end

	local function shrinkLabel(billboard: Instance)
		if not billboard:IsA("BillboardGui") or done[billboard] then
			return
		end
		done[billboard] = true
		billboard.Size = scaled(billboard.Size, labelFactor)
		for _, item in billboard:GetDescendants() do
			shrinkPart(item)
		end
		-- Contents that replicate a moment after the label itself.
		billboard.DescendantAdded:Connect(shrinkPart)
	end

	for _, gui in playerGui:GetChildren() do
		addScreenScale(gui)
	end
	playerGui.ChildAdded:Connect(addScreenScale)

	for _, item in Workspace:GetDescendants() do
		shrinkLabel(item)
	end
	Workspace.DescendantAdded:Connect(shrinkLabel)
	for _, item in playerGui:GetDescendants() do
		shrinkLabel(item)
	end
	playerGui.DescendantAdded:Connect(shrinkLabel)

	local function bindCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScreenScales)
		end
		refreshScreenScales()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()
end

return UIScaleController
