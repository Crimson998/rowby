--!strict
--[[
	Eggs, in zone order. Weights are relative; the odds shown to players are computed from these
	(with their luck applied) by Formula.eggOdds, so the displayed odds are always the real odds.
]]

export type EggPet = { Id: string, Weight: number }
export type Egg = {
	Id: string,
	Name: string,
	Zone: number,
	Price: number,
	Color: Color3,
	Accent: Color3,
	Pets: { EggPet },
}

local rgb = Color3.fromRGB

local List: { Egg } = {
	{
		Id = "Meadow",
		Name = "Meadow Egg",
		Zone = 1,
		Price = 100,
		Color = rgb(170, 230, 120),
		Accent = rgb(255, 255, 255),
		Pets = {
			{ Id = "Doggy", Weight = 62 },
			{ Id = "Kitty", Weight = 27 },
			{ Id = "Bunny", Weight = 9 },
			{ Id = "Bumblebee", Weight = 1.9 },
			{ Id = "CloverSprite", Weight = 0.1 },
		},
	},
	{
		Id = "Candy",
		Name = "Candy Egg",
		Zone = 2,
		Price = 3_000,
		Color = rgb(255, 150, 210),
		Accent = rgb(130, 230, 255),
		Pets = {
			{ Id = "GummyBear", Weight = 62 },
			{ Id = "CupcakeCat", Weight = 27 },
			{ Id = "LollipopFox", Weight = 9 },
			{ Id = "DonutDog", Weight = 1.9 },
			{ Id = "CandyDragon", Weight = 0.1 },
		},
	},
	{
		Id = "Frost",
		Name = "Frost Egg",
		Zone = 3,
		Price = 240_000,
		Color = rgb(180, 230, 255),
		Accent = rgb(255, 255, 255),
		Pets = {
			{ Id = "Penguin", Weight = 62 },
			{ Id = "SnowOwl", Weight = 27 },
			{ Id = "IceWolf", Weight = 9 },
			{ Id = "PolarBear", Weight = 1.89 },
			{ Id = "Yeti", Weight = 0.1 },
			{ Id = "FrostPhoenix", Weight = 0.01 },
		},
	},
	{
		Id = "Lava",
		Name = "Lava Egg",
		Zone = 4,
		Price = 18_000_000,
		Color = rgb(255, 110, 40),
		Accent = rgb(255, 220, 80),
		Pets = {
			{ Id = "MagmaSlime", Weight = 62 },
			{ Id = "FireImp", Weight = 27 },
			{ Id = "LavaHound", Weight = 9 },
			{ Id = "EmberGolem", Weight = 1.89 },
			{ Id = "InfernoDragon", Weight = 0.1 },
			{ Id = "Phoenix", Weight = 0.01 },
		},
	},
	{
		Id = "Cosmic",
		Name = "Cosmic Egg",
		Zone = 5,
		Price = 1_800_000_000,
		Color = rgb(120, 70, 220),
		Accent = rgb(0, 255, 225),
		Pets = {
			{ Id = "StarSprite", Weight = 62 },
			{ Id = "MoonCat", Weight = 27 },
			{ Id = "GalaxyAxolotl", Weight = 9 },
			{ Id = "CometFox", Weight = 1.889 },
			{ Id = "NebulaUnicorn", Weight = 0.1 },
			{ Id = "VoidKraken", Weight = 0.01 },
			{ Id = "Rowby", Weight = 0.001 },
		},
	},
}

local ById: { [string]: Egg } = {}
for _, egg in List do
	ById[egg.Id] = egg
end

return {
	List = List,
	ById = ById,
}
