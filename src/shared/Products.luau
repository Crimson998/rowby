--[[
	Robux catalog. Create each pass/product on the Creator Dashboard
	(Monetization → Passes / Developer Products), then paste its id into Id here.
	The Price below is only what the shop displays — keep it in sync with the dashboard.

	While an Id is 0 the item still shows in the shop. In Studio, buying it grants it for free so
	you can playtest the whole flow; in a live server the button says it isn't available yet.

	RandomItemRelated marks items that buy (or improve the odds of) random pets. They're hidden
	from players whose region restricts paid random items (PolicyService), per Roblox policy.
]]

export type Reward = {
	Gems: number?,
	CoinSeconds: number?,
	CoinBoostMinutes: number?,
	LuckBoostMinutes: number?,
	Pet: string?,
}

export type GamePass = {
	Key: string,
	Id: number,
	Name: string,
	Icon: string,
	Price: number,
	Description: string,
	RandomItemRelated: boolean?,
}

export type DevProduct = {
	Key: string,
	Id: number,
	Name: string,
	Icon: string,
	Price: number,
	Category: string,
	Description: string,
	Reward: Reward,
	OneTime: boolean?,
	Tag: string?,
	RandomItemRelated: boolean?,
}

local GamePasses: { GamePass } = {
	{
		Key = "VIP",
		Id = 0,
		Name = "VIP",
		Icon = "👑",
		Price = 199,
		Description = "+25% coins forever, +1 pet slot and a gold [VIP] chat tag.",
	},
	{
		Key = "DoubleCoins",
		Id = 0,
		Name = "2x Coins",
		Icon = "🪙",
		Price = 149,
		Description = "Permanently doubles every coin you earn.",
	},
	{
		Key = "AutoTap",
		Id = 0,
		Name = "Auto Tapper",
		Icon = "🤖",
		Price = 99,
		Description = "Taps 5 times a second for you while you play.",
	},
	{
		Key = "TripleHatch",
		Id = 0,
		Name = "Triple Hatch",
		Icon = "🥚",
		Price = 129,
		Description = "Hatch 3 eggs at once (press R at any egg).",
	},
	{
		Key = "ExtraPets",
		Id = 0,
		Name = "+3 Pet Slots",
		Icon = "🐾",
		Price = 99,
		Description = "Equip 3 more pets at the same time.",
	},
	{
		Key = "Lucky",
		Id = 0,
		Name = "Lucky Eggs",
		Icon = "🍀",
		Price = 149,
		Description = "+25% luck on every egg. The odds on each egg include it.",
		RandomItemRelated = true,
	},
}

local DevProducts: { DevProduct } = {
	{
		Key = "StarterPack",
		Id = 0,
		Name = "Starter Pack",
		Icon = "🎁",
		Price = 49,
		Category = "Featured",
		Description = "250 Gems, 30 min of 2x Coins and the exclusive Starter Pup. One per player.",
		Reward = { Gems = 250, CoinBoostMinutes = 30, Pet = "StarterPup" },
		OneTime = true,
		Tag = "BEST VALUE",
	},
	{
		Key = "BoostCoins",
		Id = 0,
		Name = "2x Coins · 15 min",
		Icon = "⚡",
		Price = 25,
		Category = "Boosts",
		Description = "Double coins for 15 minutes of play. Stacks with passes.",
		Reward = { CoinBoostMinutes = 15 },
	},
	{
		Key = "BoostLuck",
		Id = 0,
		Name = "2x Luck · 15 min",
		Icon = "🍀",
		Price = 25,
		Category = "Boosts",
		Description = "Double luck for 15 minutes of play. Odds on eggs update live.",
		Reward = { LuckBoostMinutes = 15 },
		RandomItemRelated = true,
	},
	{
		Key = "CoinsSmall",
		Id = 0,
		Name = "Pile of Coins",
		Icon = "🪙",
		Price = 19,
		Category = "Coins",
		Description = "10 minutes of tapping, instantly.",
		Reward = { CoinSeconds = 600 },
		RandomItemRelated = true,
	},
	{
		Key = "CoinsMedium",
		Id = 0,
		Name = "Sack of Coins",
		Icon = "💰",
		Price = 69,
		Category = "Coins",
		Description = "50 minutes of tapping, instantly.",
		Reward = { CoinSeconds = 3000 },
		Tag = "+38%",
		RandomItemRelated = true,
	},
	{
		Key = "CoinsLarge",
		Id = 0,
		Name = "Vault of Coins",
		Icon = "🏦",
		Price = 179,
		Category = "Coins",
		Description = "3 hours of tapping, instantly.",
		Reward = { CoinSeconds = 10800 },
		Tag = "+91%",
		RandomItemRelated = true,
	},
	{
		Key = "GemsSmall",
		Id = 0,
		Name = "Handful of Gems",
		Icon = "💎",
		Price = 19,
		Category = "Gems",
		Description = "100 Gems for upgrades.",
		Reward = { Gems = 100 },
	},
	{
		Key = "GemsMedium",
		Id = 0,
		Name = "Chest of Gems",
		Icon = "💎",
		Price = 79,
		Category = "Gems",
		Description = "550 Gems for upgrades.",
		Reward = { Gems = 550 },
		Tag = "+32%",
	},
	{
		Key = "GemsLarge",
		Id = 0,
		Name = "Mountain of Gems",
		Icon = "💎",
		Price = 199,
		Category = "Gems",
		Description = "1,600 Gems for upgrades.",
		Reward = { Gems = 1600 },
		Tag = "+53%",
	},
}

local PassByKey: { [string]: GamePass } = {}
for _, pass in GamePasses do
	PassByKey[pass.Key] = pass
end

local ProductByKey: { [string]: DevProduct } = {}
for _, product in DevProducts do
	ProductByKey[product.Key] = product
end

return {
	GamePasses = GamePasses,
	DevProducts = DevProducts,
	PassByKey = PassByKey,
	ProductByKey = ProductByKey,
	Categories = { "Featured", "Boosts", "Coins", "Gems" },
}
