--[[
	Quests track a lifetime stat from a starting point, so progress needs no extra hooks:
	progress = Stats[Stat] - Start. Goals scale with how many quests the player has finished.
]]

local Formula = require(script.Parent.Formula)

export type Template = {
	Stat: string,
	Text: string,
	Icon: string,
	Gems: number,
	Goal: (data: any, session: any) -> number,
}

local Templates: { Template } = {
	{
		Stat = "Taps",
		Text = "Tap %s times",
		Icon = "👆",
		Gems = 8,
		Goal = function(data)
			return 150 + 25 * math.min(data.QuestsCompleted, 40)
		end,
	},
	{
		Stat = "EggsHatched",
		Text = "Hatch %s eggs",
		Icon = "🥚",
		Gems = 12,
		Goal = function(data)
			return 3 + math.min(data.QuestsCompleted // 3, 12)
		end,
	},
	{
		Stat = "OrbsCollected",
		Text = "Collect %s orbs",
		Icon = "✨",
		Gems = 10,
		Goal = function(data)
			return 20 + 5 * math.min(data.QuestsCompleted, 20)
		end,
	},
	{
		Stat = "CoinsEarned",
		Text = "Earn %s coins",
		Icon = "🪙",
		Gems = 12,
		Goal = function(data, session)
			return Formula.rewardCoins(data, session, 240)
		end,
	},
}

local ByStat: { [string]: Template } = {}
for _, template in Templates do
	ByStat[template.Stat] = template
end

local Quests = {
	Templates = Templates,
	ByStat = ByStat,
	Slots = 3,
}

function Quests.progress(data, quest): number
	return math.clamp((data.Stats[quest.Stat] or 0) - quest.Start, 0, quest.Goal)
end

return Quests
