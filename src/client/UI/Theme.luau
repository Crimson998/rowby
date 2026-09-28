--!strict
--[[
	Shared look for every screen: colours, font and the sizes that keep spacing consistent.
]]

local rgb = Color3.fromRGB

return {
	Font = Enum.Font.FredokaOne,
	Colors = {
		Background = rgb(24, 26, 44),
		Panel = rgb(38, 42, 68),
		PanelLight = rgb(56, 61, 96),
		Stroke = rgb(12, 13, 24),
		Text = rgb(255, 255, 255),
		SubText = rgb(180, 188, 222),
		Coins = rgb(255, 205, 60),
		Gems = rgb(90, 220, 255),
		Luck = rgb(90, 225, 110),
		Rebirth = rgb(255, 115, 215),
		Green = rgb(60, 200, 95),
		Red = rgb(235, 75, 90),
		Blue = rgb(65, 140, 255),
		Purple = rgb(150, 95, 255),
		Orange = rgb(255, 140, 45),
		Gray = rgb(105, 112, 145),
		Gold = rgb(255, 195, 40),
		Disabled = rgb(78, 82, 104),
	},
	-- Corner radius for panels and buttons, and the outline width around them.
	Radius = 14,
	StrokeWidth = 2,
	-- Space between neighbouring elements, and from the screen edges.
	Gap = 8,
	Margin = 12,
	-- Square HUD menu buttons.
	Tile = 80,
}
