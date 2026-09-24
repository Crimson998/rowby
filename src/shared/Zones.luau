--[[
	Areas laid end to end along +Z. Unlocking an area permanently raises the tap multiplier to
	that area's TapMultiplier and opens its egg and clovers. Visual theme values are read by the
	server's world builder and by the client when you walk between areas.
]]

export type Zone = {
	Index: number,
	Name: string,
	Icon: string,
	UnlockCost: number,
	TapMultiplier: number,
	-- Luck XP per clover picked up here.
	CloverValue: number,
	Theme: string,
	Ground: Color3,
	GroundMaterial: Enum.Material,
	Accent: Color3,
	ClockTime: number,
	AtmosphereColor: Color3,
	AtmosphereDecay: Color3,
	AtmosphereDensity: number,
}

local rgb = Color3.fromRGB

local List: { Zone } = {
	{
		Index = 1,
		Name = "Sunny Meadow",
		Icon = "🌼",
		UnlockCost = 0,
		TapMultiplier = 1,
		CloverValue = 1,
		Theme = "Meadow",
		Ground = rgb(110, 190, 85),
		GroundMaterial = Enum.Material.Grass,
		Accent = rgb(255, 225, 90),
		ClockTime = 14,
		AtmosphereColor = rgb(200, 225, 255),
		AtmosphereDecay = rgb(120, 170, 230),
		AtmosphereDensity = 0.25,
	},
	{
		Index = 2,
		Name = "Candy Kingdom",
		Icon = "🍭",
		UnlockCost = 12_000,
		TapMultiplier = 1.5,
		CloverValue = 2,
		Theme = "Candy",
		Ground = rgb(255, 185, 220),
		GroundMaterial = Enum.Material.SmoothPlastic,
		Accent = rgb(130, 230, 255),
		ClockTime = 15.5,
		AtmosphereColor = rgb(255, 205, 235),
		AtmosphereDecay = rgb(255, 150, 210),
		AtmosphereDensity = 0.3,
	},
	{
		Index = 3,
		Name = "Frosty Peaks",
		Icon = "❄️",
		UnlockCost = 1_200_000,
		TapMultiplier = 2.25,
		CloverValue = 3,
		Theme = "Frost",
		Ground = rgb(235, 245, 255),
		GroundMaterial = Enum.Material.Snow,
		Accent = rgb(140, 210, 255),
		ClockTime = 10,
		AtmosphereColor = rgb(225, 240, 255),
		AtmosphereDecay = rgb(170, 210, 255),
		AtmosphereDensity = 0.4,
	},
	{
		Index = 4,
		Name = "Lava Land",
		Icon = "🌋",
		UnlockCost = 150_000_000,
		TapMultiplier = 3.5,
		CloverValue = 4,
		Theme = "Lava",
		Ground = rgb(70, 45, 40),
		GroundMaterial = Enum.Material.Basalt,
		Accent = rgb(255, 110, 30),
		ClockTime = 18,
		AtmosphereColor = rgb(255, 150, 110),
		AtmosphereDecay = rgb(200, 70, 40),
		AtmosphereDensity = 0.45,
	},
	{
		Index = 5,
		Name = "Cosmic Void",
		Icon = "🌌",
		UnlockCost = 15_000_000_000,
		TapMultiplier = 5,
		CloverValue = 5,
		Theme = "Cosmic",
		Ground = rgb(30, 20, 55),
		GroundMaterial = Enum.Material.Slate,
		Accent = rgb(0, 255, 225),
		ClockTime = 0,
		AtmosphereColor = rgb(150, 110, 255),
		AtmosphereDecay = rgb(70, 30, 140),
		AtmosphereDensity = 0.35,
	},
}

-- World layout shared by the server builder and client (zone detection, guide beams).
local Layout = {
	Width = 200,
	Length = 200,
}

local function indexAt(z: number): number
	local index = math.floor(z / Layout.Length) + 1
	return math.clamp(index, 1, #List)
end

local function center(index: number): Vector3
	return Vector3.new(0, 0, (index - 0.5) * Layout.Length)
end

return {
	List = List,
	Layout = Layout,
	indexAt = indexAt,
	center = center,
}
