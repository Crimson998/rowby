--[[
	Central tuning knobs. Pacing lives here and in Pets/Eggs/Zones/Upgrades/Products,
	so balancing the game never requires touching gameplay code.
]]

local Config = {}

-- Who can open the 🛠 Admin panel. Everyone is an admin in Studio; in live servers the place
-- owner (or, for group games, members at GroupMinRank or above) plus these user ids.
Config.Admins = {
	UserIds = {},
	GroupMinRank = 254,
}

Config.GameName = "Tap & Hatch Alpha"

Config.Data = {
	StoreName = "TapAndHatch_Players_v1",
	AutosaveSeconds = 60,
	-- A session lock older than this is treated as abandoned (crashed server) and can be taken over.
	SessionLockSeconds = 1800,
}

Config.Tap = {
	-- Server-side cap so macros can't outpace real fingers.
	MaxPerSecond = 14,
	-- Taps per second granted by the Auto Tapper pass.
	AutoPerSecond = 5,
	-- Used to turn "seconds of earnings" rewards into coins.
	EstimatedPerSecond = 5,
}

Config.Pets = {
	BaseEquipSlots = 3,
	Storage = 150,
	-- Copies of one pet at one tier that combine into one pet of the next tier (see Config.Tiers).
	CraftCopies = 5,
	HatchCooldown = 1.3,
	HatchRange = 20,
	-- Rarities players may auto-delete on hatch (Settings). Rarer pets are always kept.
	AutoDeletable = { "Common", "Uncommon", "Rare", "Epic" },
}

-- Pet tiers, lowest first. CraftCopies pets of a tier combine into one of the next tier, and a
-- pet's power is multiplied by its tier's Multiplier. Tier 1 uses the pet's own colours; higher
-- tiers repaint it (or use a "<PetId>_<Name>" custom model, see CustomModels.luau).
local rgb = Color3.fromRGB
Config.Tiers = {
	{ Name = "Normal", Icon = "", Multiplier = 1 },
	{
		Name = "Golden",
		Icon = "⭐",
		Multiplier = 3,
		Color = rgb(255, 200, 45),
		Accent = rgb(255, 240, 160),
		Reflectance = 0.25,
	},
	{
		Name = "Diamond",
		Icon = "💎",
		Multiplier = 8,
		Color = rgb(165, 235, 255),
		Accent = rgb(255, 255, 255),
		Reflectance = 0.4,
		NeonAccent = true,
	},
	{
		Name = "Emerald",
		Icon = "💚",
		Multiplier = 20,
		Color = rgb(35, 205, 115),
		Accent = rgb(185, 255, 215),
		Reflectance = 0.35,
		NeonAccent = true,
	},
	{
		Name = "Void",
		Icon = "🌀",
		Multiplier = 50,
		Color = rgb(30, 12, 50),
		Accent = rgb(185, 95, 255),
		Reflectance = 0.1,
		NeonAccent = true,
	},
}

Config.Rebirth = {
	BaseCost = 250_000,
	CostGrowth = 3.2,
	MultiplierPerRebirth = 0.5,
	BaseGems = 20,
	GemsPerRebirth = 5,
}

-- Clovers on the ground. Coins only come from tapping; clovers build your Luck level.
-- Each clover gives the area's CloverValue in Luck XP (see Zones.luau).
Config.Orbs = {
	PerZone = 18,
	RespawnSeconds = 3,
	-- Chance a clover spawns as a golden Lucky Clover worth LuckyMultiplier times as much.
	LuckyChance = 0.04,
	LuckyMultiplier = 10,
	BaseMagnetRadius = 7,
	MagnetPerLevel = 3,
}

-- Luck level from clovers. Reaching level L takes BaseXP * L^Exponent Luck XP in total,
-- and every level adds PerLevel to your luck (0.02 = +2%). Luck is never lost on rebirth.
Config.Luck = {
	BaseXP = 20,
	Exponent = 1.6,
	PerLevel = 0.02,
	MaxLevel = 200,
}

Config.WalkSpeed = {
	Base = 18,
	PerLevel = 2,
}

Config.Bonuses = {
	VIPCoinMultiplier = 1.25,
	DoubleCoinsMultiplier = 2,
	PremiumCoinBonus = 0.1,
	FriendBonusPerFriend = 0.1,
	MaxFriendBonus = 0.5,
	LuckyPassLuck = 0.25,
	CoinBoostMultiplier = 2,
	LuckBoostMultiplier = 2,
	VIPExtraSlots = 1,
	ExtraPetsPassSlots = 3,
}

--[[
	Reward tables are shared by daily rewards, playtime gifts, quests and codes:
		Gems              flat gems
		CoinSeconds       coins equal to this many seconds of tapping at your current power
		CoinBoostMinutes  minutes of 2x Coins
		LuckBoostMinutes  minutes of 2x Luck
]]
Config.Daily = {
	CooldownHours = 20,
	StreakResetHours = 48,
	Rewards = {
		{ Gems = 10, CoinSeconds = 60 },
		{ Gems = 15, CoinSeconds = 90 },
		{ Gems = 20, CoinBoostMinutes = 10 },
		{ Gems = 30, CoinSeconds = 180 },
		{ Gems = 40, LuckBoostMinutes = 10 },
		{ Gems = 60, CoinSeconds = 300 },
		{ Gems = 120, CoinBoostMinutes = 20, LuckBoostMinutes = 20 },
	},
}

-- Gifts unlock by minutes played in the current session.
Config.Gifts = {
	{ Minutes = 1, Reward = { CoinSeconds = 30 } },
	{ Minutes = 3, Reward = { Gems = 5 } },
	{ Minutes = 5, Reward = { CoinBoostMinutes = 5 } },
	{ Minutes = 8, Reward = { CoinSeconds = 90 } },
	{ Minutes = 12, Reward = { Gems = 15 } },
	{ Minutes = 18, Reward = { LuckBoostMinutes = 10 } },
	{ Minutes = 25, Reward = { CoinSeconds = 240 } },
	{ Minutes = 35, Reward = { Gems = 40, CoinBoostMinutes = 10 } },
}

-- Codes are case-insensitive. Share them on your group/Discord/socials.
Config.Codes = {
	RELEASE = { Gems = 50 },
	TAPTAP = { CoinBoostMinutes = 15 },
	LUCKY = { LuckBoostMinutes = 15 },
}

Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

-- Luck multiplies the weight of every rarity marked Lucky. Announce broadcasts the hatch server-wide.
Config.Rarities = {
	Common = { Color = Color3.fromRGB(200, 200, 200), Lucky = false, DiscoveryGems = 2 },
	Uncommon = { Color = Color3.fromRGB(100, 220, 100), Lucky = false, DiscoveryGems = 3 },
	Rare = { Color = Color3.fromRGB(70, 155, 255), Lucky = true, DiscoveryGems = 5 },
	Epic = { Color = Color3.fromRGB(175, 90, 255), Lucky = true, DiscoveryGems = 10 },
	Legendary = { Color = Color3.fromRGB(255, 175, 30), Lucky = true, DiscoveryGems = 25, Announce = true },
	Mythic = { Color = Color3.fromRGB(255, 60, 95), Lucky = true, DiscoveryGems = 50, Announce = true },
	Secret = { Color = Color3.fromRGB(0, 255, 225), Lucky = true, DiscoveryGems = 150, Announce = true },
}

-- Built-in engine sounds so the place works without uploading audio. Swap for your own asset ids.
Config.Sounds = {
	Tap = "rbxasset://sounds/clickfast.wav",
	Coin = "rbxasset://sounds/electronicpingshort.wav",
	Hatch = "rbxasset://sounds/swoosh.wav",
	Reveal = "rbxasset://sounds/victory.wav",
	Click = "rbxasset://sounds/button.wav",
	Error = "rbxasset://sounds/clickfast.wav",
}

return Config
