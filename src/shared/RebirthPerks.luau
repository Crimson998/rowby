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
	-- Effect of one level: pet storage slots, seconds of tapping to start a run with, or the
	-- fraction of extra gems from rebirthing.
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
}

local ById: { [string]: Perk } = {}
for _, perk in List do
	ById[perk.Id] = perk
end

return {
	List = List,
	ById = ById,
}
