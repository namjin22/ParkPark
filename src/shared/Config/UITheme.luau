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
}

return UITheme
