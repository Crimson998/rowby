--[[
	Every pet in the game. Power is added to the player's coin multiplier while the pet is
	equipped (golden pets multiply it by Config.Pets.GoldenMultiplier).

	Looks are generated from Color/Accent/Features by the client's PetModels module, so new
	pets need no modelling: pick colours and any of
		DogEars, CatEars, BunnyEars, BearEars, Wings, Antenna, Horns, Horn, Halo, Beak, Crown, Tentacles
	Shape = "Blob" squashes the body; Neon = true makes the accent glow.
]]

export type Pet = {
	Name: string,
	Rarity: string,
	Power: number,
	Color: Color3,
	Accent: Color3,
	Features: { string },
	Shape: string?,
	Neon: boolean?,
	Exclusive: boolean?,
}

local rgb = Color3.fromRGB

local Pets: { [string]: Pet } = {
	-- Sunny Meadow
	Doggy = {
		Name = "Doggy",
		Rarity = "Common",
		Power = 0.2,
		Color = rgb(205, 155, 105),
		Accent = rgb(125, 85, 55),
		Features = { "DogEars" },
	},
	Kitty = {
		Name = "Kitty",
		Rarity = "Uncommon",
		Power = 0.35,
		Color = rgb(255, 170, 80),
		Accent = rgb(255, 235, 205),
		Features = { "CatEars" },
	},
	Bunny = {
		Name = "Bunny",
		Rarity = "Rare",
		Power = 0.6,
		Color = rgb(250, 250, 250),
		Accent = rgb(255, 170, 195),
		Features = { "BunnyEars" },
	},
	Bumblebee = {
		Name = "Bumblebee",
		Rarity = "Epic",
		Power = 1.2,
		Color = rgb(255, 210, 40),
		Accent = rgb(45, 45, 45),
		Features = { "Wings", "Antenna" },
	},
	CloverSprite = {
		Name = "Clover Sprite",
		Rarity = "Legendary",
		Power = 3,
		Color = rgb(90, 220, 110),
		Accent = rgb(255, 255, 210),
		Features = { "Wings", "Halo" },
		Neon = true,
	},

	-- Candy Kingdom
	GummyBear = {
		Name = "Gummy Bear",
		Rarity = "Common",
		Power = 1,
		Color = rgb(255, 90, 110),
		Accent = rgb(255, 160, 170),
		Features = { "BearEars" },
	},
	CupcakeCat = {
		Name = "Cupcake Cat",
		Rarity = "Uncommon",
		Power = 1.6,
		Color = rgb(255, 185, 220),
		Accent = rgb(140, 90, 60),
		Features = { "CatEars" },
	},
	LollipopFox = {
		Name = "Lollipop Fox",
		Rarity = "Rare",
		Power = 2.8,
		Color = rgb(255, 125, 50),
		Accent = rgb(255, 255, 255),
		Features = { "CatEars" },
	},
	DonutDog = {
		Name = "Donut Dog",
		Rarity = "Epic",
		Power = 5,
		Color = rgb(230, 170, 110),
		Accent = rgb(255, 100, 200),
		Features = { "DogEars", "Crown" },
	},
	CandyDragon = {
		Name = "Candy Dragon",
		Rarity = "Legendary",
		Power = 12,
		Color = rgb(255, 110, 200),
		Accent = rgb(120, 255, 230),
		Features = { "Horns", "Wings" },
		Neon = true,
	},

	-- Frosty Peaks
	Penguin = {
		Name = "Penguin",
		Rarity = "Common",
		Power = 5,
		Color = rgb(45, 45, 65),
		Accent = rgb(255, 255, 255),
		Features = { "Beak" },
	},
	SnowOwl = {
		Name = "Snow Owl",
		Rarity = "Uncommon",
		Power = 8,
		Color = rgb(240, 245, 255),
		Accent = rgb(255, 200, 60),
		Features = { "Beak", "Wings" },
	},
	IceWolf = {
		Name = "Ice Wolf",
		Rarity = "Rare",
		Power = 14,
		Color = rgb(170, 220, 255),
		Accent = rgb(255, 255, 255),
		Features = { "CatEars" },
	},
	PolarBear = {
		Name = "Polar Bear",
		Rarity = "Epic",
		Power = 25,
		Color = rgb(250, 250, 255),
		Accent = rgb(45, 45, 45),
		Features = { "BearEars" },
	},
	Yeti = {
		Name = "Yeti",
		Rarity = "Legendary",
		Power = 60,
		Color = rgb(220, 240, 255),
		Accent = rgb(90, 160, 255),
		Features = { "Horns" },
		Neon = true,
	},
	FrostPhoenix = {
		Name = "Frost Phoenix",
		Rarity = "Mythic",
		Power = 150,
		Color = rgb(100, 200, 255),
		Accent = rgb(255, 255, 255),
		Features = { "Wings", "Crown" },
		Neon = true,
	},

	-- Lava Land
	MagmaSlime = {
		Name = "Magma Slime",
		Rarity = "Common",
		Power = 25,
		Color = rgb(255, 110, 40),
		Accent = rgb(120, 30, 10),
		Features = {},
		Shape = "Blob",
	},
	FireImp = {
		Name = "Fire Imp",
		Rarity = "Uncommon",
		Power = 40,
		Color = rgb(220, 50, 40),
		Accent = rgb(255, 200, 60),
		Features = { "Horns" },
	},
	LavaHound = {
		Name = "Lava Hound",
		Rarity = "Rare",
		Power = 70,
		Color = rgb(70, 40, 40),
		Accent = rgb(255, 120, 30),
		Features = { "DogEars" },
		Neon = true,
	},
	EmberGolem = {
		Name = "Ember Golem",
		Rarity = "Epic",
		Power = 125,
		Color = rgb(90, 80, 80),
		Accent = rgb(255, 90, 20),
		Features = { "Crown" },
		Neon = true,
	},
	InfernoDragon = {
		Name = "Inferno Dragon",
		Rarity = "Legendary",
		Power = 300,
		Color = rgb(200, 30, 30),
		Accent = rgb(255, 170, 0),
		Features = { "Horns", "Wings" },
		Neon = true,
	},
	Phoenix = {
		Name = "Phoenix",
		Rarity = "Mythic",
		Power = 750,
		Color = rgb(255, 140, 0),
		Accent = rgb(255, 240, 120),
		Features = { "Wings", "Halo" },
		Neon = true,
	},

	-- Cosmic Void
	StarSprite = {
		Name = "Star Sprite",
		Rarity = "Common",
		Power = 120,
		Color = rgb(255, 240, 150),
		Accent = rgb(255, 255, 255),
		Features = { "Antenna" },
	},
	MoonCat = {
		Name = "Moon Cat",
		Rarity = "Uncommon",
		Power = 200,
		Color = rgb(180, 180, 220),
		Accent = rgb(255, 255, 180),
		Features = { "CatEars" },
	},
	GalaxyAxolotl = {
		Name = "Galaxy Axolotl",
		Rarity = "Rare",
		Power = 350,
		Color = rgb(220, 110, 255),
		Accent = rgb(120, 220, 255),
		Features = { "Antenna" },
		Neon = true,
	},
	CometFox = {
		Name = "Comet Fox",
		Rarity = "Epic",
		Power = 600,
		Color = rgb(80, 140, 255),
		Accent = rgb(255, 255, 255),
		Features = { "CatEars", "Halo" },
		Neon = true,
	},
	NebulaUnicorn = {
		Name = "Nebula Unicorn",
		Rarity = "Legendary",
		Power = 1500,
		Color = rgb(255, 120, 230),
		Accent = rgb(140, 100, 255),
		Features = { "Horn", "Wings" },
		Neon = true,
	},
	VoidKraken = {
		Name = "Void Kraken",
		Rarity = "Mythic",
		Power = 4000,
		Color = rgb(45, 20, 75),
		Accent = rgb(170, 80, 255),
		Features = { "Tentacles", "Crown" },
		Neon = true,
	},
	Rowby = {
		Name = "Rowby",
		Rarity = "Secret",
		Power = 15000,
		Color = rgb(0, 255, 220),
		Accent = rgb(255, 255, 255),
		Features = { "Crown", "Halo", "Wings" },
		Neon = true,
	},

	-- Starter Pack exclusive (sold directly, never random)
	StarterPup = {
		Name = "Starter Pup",
		Rarity = "Epic",
		Power = 3,
		Color = rgb(120, 200, 255),
		Accent = rgb(255, 255, 255),
		Features = { "DogEars", "Crown" },
		Exclusive = true,
	},
}

return Pets
