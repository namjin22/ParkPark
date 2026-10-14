--!strict

-- Interface colours shared by the client panels: flat light panels with a thin neutral border and dark text.
-- The world signs keep the park palette (GameConfig.Palette); this is only for screen UI.
local UITheme = {
	Panel = Color3.fromRGB(250, 249, 246),
	Border = Color3.fromRGB(208, 204, 196),
	Text = Color3.fromRGB(40, 44, 48),
	Muted = Color3.fromRGB(108, 114, 118),
	Button = Color3.fromRGB(238, 235, 228),
	ButtonOn = Color3.fromRGB(190, 224, 208),
	Accent = Color3.fromRGB(70, 150, 120),
	Warn = Color3.fromRGB(196, 84, 70),

	-- The menu buttons (이동, 꾸미기, 미션, 도감, 친구 공원, 음악) share one small strip: a row under the guide card on
	-- wide screens, a column on the right edge of tall phones. Panels open just below the row (or beside the column).
	MenuButtonWidth = 60,
	MenuButtonHeight = 28,
	MenuGap = 4,
	MenuTextSize = 12,
	MenuRowY = 132,
	MenuPanelTop = 168,
	MenuColumnY = 0.34,
}

-- Where menu button number `index` (1-based) sits.
function UITheme.MenuSlot(index: number, portrait: boolean): (Vector2, UDim2)
	local step = UITheme.MenuGap + (if portrait then UITheme.MenuButtonHeight else UITheme.MenuButtonWidth)
	if portrait then
		return Vector2.new(1, 0), UDim2.new(1, -10, UITheme.MenuColumnY, (index - 1) * step)
	end
	return Vector2.new(0, 0), UDim2.fromOffset(16 + (index - 1) * step, UITheme.MenuRowY)
end

-- Where a menu panel opens: below the row, or to the left of the column.
function UITheme.MenuPanel(portrait: boolean): (Vector2, UDim2)
	if portrait then
		return Vector2.new(1, 0), UDim2.new(1, -(UITheme.MenuButtonWidth + 18), UITheme.MenuColumnY, 0)
	end
	return Vector2.new(0, 0), UDim2.fromOffset(16, UITheme.MenuPanelTop)
end

-- Height of a ScreenGui's own canvas in its layout units: below Roblox's top bar and before its UIScale, which is
-- what a panel's offsets are measured in. (The camera's viewport includes the top bar and ignores the scale.)
function UITheme.CanvasHeight(gui: LayerCollector): number
	local scale = gui:FindFirstChildOfClass("UIScale")
	return gui.AbsoluteSize.Y / (if scale and scale.Scale > 0 then scale.Scale else 1)
end

-- How tall a menu panel may be before it reaches the bottom of the screen.
function UITheme.MenuPanelRoom(gui: LayerCollector, portrait: boolean): number
	local height = UITheme.CanvasHeight(gui)
	local top = if portrait then height * UITheme.MenuColumnY else UITheme.MenuPanelTop
	return height - top - 12
end

-- Tall, narrow screens (phones held upright).
function UITheme.IsPortrait(viewport: Vector2): boolean
	return viewport.X < 550 and viewport.Y > viewport.X
end

-- One menu button in the shared style.
function UITheme.MenuButton(text: string, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(UITheme.MenuButtonWidth, UITheme.MenuButtonHeight)
	button.BackgroundColor3 = UITheme.Button
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = UITheme.Text
	button.TextSize = UITheme.MenuTextSize
	button.AutoButtonColor = true
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = UITheme.Border
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	return button
end

return UITheme
