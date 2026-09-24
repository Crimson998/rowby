--[[
	Permanent upgrades. Coin upgrades are the moment-to-moment sink; gem upgrades are the
	long-term sink fed by rebirths, dailies, quests and gifts. Costs grow by Growth per level
	unless an explicit Costs list is given.
]]

export type Upgrade = {
	Id: string,
	Name: string,
	Icon: string,
	Currency: string,
	MaxLevel: number,
	BaseCost: number?,
	Growth: number?,
	Costs: { number }?,
	ResetsOnRebirth: boolean?,
	Description: string,
}

local List: { Upgrade } = {
	{
		Id = "TapPower",
		Name = "Tap Power",
		Icon = "👆",
		Currency = "Coins",
		MaxLevel = 250,
		BaseCost = 15,
		Growth = 1.22,
		ResetsOnRebirth = true,
		Description = "More coins from every tap.",
	},
	{
		Id = "Magnet",
		Name = "Orb Magnet",
		Icon = "🧲",
		Currency = "Coins",
		MaxLevel = 10,
		BaseCost = 300,
		Growth = 3.2,
		Description = "Grab orbs from farther away.",
	},
	{
		Id = "WalkSpeed",
		Name = "Swift Shoes",
		Icon = "👟",
		Currency = "Coins",
		MaxLevel = 10,
		BaseCost = 200,
		Growth = 2.8,
		Description = "Run faster between orbs and eggs.",
	},
	{
		Id = "PetSlots",
		Name = "Pet Slots",
		Icon = "🐾",
		Currency = "Gems",
		MaxLevel = 4,
		Costs = { 60, 180, 450, 1100 },
		Description = "Equip one more pet.",
	},
	{
		Id = "Luck",
		Name = "Egg Luck",
		Icon = "🍀",
		Currency = "Gems",
		MaxLevel = 10,
		BaseCost = 40,
		Growth = 1.55,
		Description = "+10% chance for Rare and better pets.",
	},
	{
		Id = "CoinMastery",
		Name = "Coin Mastery",
		Icon = "💰",
		Currency = "Gems",
		MaxLevel = 25,
		BaseCost = 30,
		Growth = 1.35,
		Description = "+10% coins from everything.",
	},
}

local ById: { [string]: Upgrade } = {}
for _, upgrade in List do
	ById[upgrade.Id] = upgrade
end

return {
	List = List,
	ById = ById,
}
