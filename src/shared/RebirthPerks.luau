--!strict
--[[
	The Rebirth shop. Every rebirth earns one Rebirth Token (tokens = Rebirths minus the tokens
	already spent), spent on permanent perks that survive rebirthing. Costs are in tokens, one per
	level in Costs.
]]

export type Perk = {
	Id: string,
	Name: string,
	Icon: string,
	Costs: { number },
	-- Effect of one level: pet storage slots, seconds of tapping to start a run with, the fraction
	-- of extra gems from rebirthing, studs of clover pickup range, the fraction of extra coins, or
	-- clovers grabbed per auto-collect sweep, the luck added, or seconds added to the clover streak window.
	PerLevel: number,
	Description: string,
}

local List: { Perk } = {
	{
		Id = "Storage",
		Name = "Bigger Storage",
		Icon = "📦",
		Costs = { 1, 1, 2, 2, 3, 3 },
		PerLevel = 25,
		Description = "+25 pet storage per level.",
	},
	{
		Id = "HeadStart",
		Name = "Head Start",
		Icon = "🚀",
		Costs = { 1, 2, 3, 4, 5 },
		PerLevel = 60,
		Description = "Each rebirth starts with a minute of tapping per level in coins.",
	},
	{
		Id = "GemFinder",
		Name = "Gem Finder",
		Icon = "💎",
		Costs = { 2, 3, 4, 5 },
		PerLevel = 0.25,
		Description = "+25% gems from every rebirth per level.",
	},
	{
		Id = "WideMagnet",
		Name = "Wide Magnet",
		Icon = "🧲",
		Costs = { 1, 2, 3, 4 },
		PerLevel = 4,
		Description = "+4 studs of clover pickup range per level, on top of Magnet.",
	},
	{
		Id = "CoinBonus",
		Name = "Coin Surge",
		Icon = "🪙",
		Costs = { 2, 3, 4, 5, 6 },
		PerLevel = 0.05,
		Description = "+5% coins from everything per level.",
	},
	{
		Id = "AutoCollect",
		Name = "Auto Collect",
		Icon = "🤖",
		Costs = { 2, 3, 5 },
		PerLevel = 1,
		Description = "Every few seconds, grabs 1 clover per level anywhere in your area, no walking needed.",
	},
	{
		Id = "LuckyCharm",
		Name = "Lucky Charm",
		Icon = "🍀",
		Costs = { 3, 4, 5, 6 },
		PerLevel = 0.1,
		Description = "+10% luck per level, added to your other luck.",
	},
	{
		Id = "StreakKeeper",
		Name = "Streak Keeper",
		Icon = "🔥",
		Costs = { 1, 2, 3 },
		PerLevel = 0.5,
		Description = "+0.5s to the time you have between clovers before your streak resets, per level.",
	},
}

local ById: { [string]: Perk } = {}
for _, perk in List do
	ById[perk.Id] = perk
end

return {
	List = List,
	ById = ById,
}
