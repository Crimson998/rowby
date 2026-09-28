--!strict
--[[
	One-time milestones. Unlike quests, each is claimed once for a fixed gem reward: progress
	reads straight from lifetime stats (or from a Data field, for Rebirths/HighestZone/Index), so
	the only extra state needed is Data.Achievements, the set of ids already claimed.
]]

local Pets = require(script.Parent.Pets)
local Zones = require(script.Parent.Zones)

export type Template = {
	Id: string,
	Text: string,
	Icon: string,
	Goal: number,
	Gems: number,
	Value: (data: any) -> number,
}

local totalPets = 0
for _ in Pets do
	totalPets += 1
end

local function stat(name: string): (data: any) -> number
	return function(data)
		return data.Stats[name] or 0
	end
end

local function field(name: string): (data: any) -> number
	return function(data)
		return data[name] or 0
	end
end

local function petsDiscovered(data: any): number
	local count = 0
	for _ in data.Index do
		count += 1
	end
	return count
end

local Templates: { Template } = {
	{ Id = "Taps1", Text = "Tap %s times", Icon = "👆", Goal = 100, Gems = 5, Value = stat("Taps") },
	{ Id = "Taps2", Text = "Tap %s times", Icon = "👆", Goal = 1_000, Gems = 15, Value = stat("Taps") },
	{ Id = "Taps3", Text = "Tap %s times", Icon = "👆", Goal = 10_000, Gems = 40, Value = stat("Taps") },
	{ Id = "Taps4", Text = "Tap %s times", Icon = "👆", Goal = 100_000, Gems = 100, Value = stat("Taps") },

	{ Id = "Coins1", Text = "Earn %s coins", Icon = "🪙", Goal = 10_000, Gems = 8, Value = stat("CoinsEarned") },
	{ Id = "Coins2", Text = "Earn %s coins", Icon = "🪙", Goal = 250_000, Gems = 25, Value = stat("CoinsEarned") },
	{ Id = "Coins3", Text = "Earn %s coins", Icon = "🪙", Goal = 5_000_000, Gems = 60, Value = stat("CoinsEarned") },
	{
		Id = "Coins4",
		Text = "Earn %s coins",
		Icon = "🪙",
		Goal = 250_000_000,
		Gems = 150,
		Value = stat("CoinsEarned"),
	},

	{ Id = "Eggs1", Text = "Hatch %s eggs", Icon = "🥚", Goal = 10, Gems = 8, Value = stat("EggsHatched") },
	{ Id = "Eggs2", Text = "Hatch %s eggs", Icon = "🥚", Goal = 50, Gems = 20, Value = stat("EggsHatched") },
	{ Id = "Eggs3", Text = "Hatch %s eggs", Icon = "🥚", Goal = 250, Gems = 50, Value = stat("EggsHatched") },
	{ Id = "Eggs4", Text = "Hatch %s eggs", Icon = "🥚", Goal = 1_000, Gems = 120, Value = stat("EggsHatched") },

	{ Id = "Orbs1", Text = "Pick up %s clovers", Icon = "🍀", Goal = 50, Gems = 6, Value = stat("OrbsCollected") },
	{ Id = "Orbs2", Text = "Pick up %s clovers", Icon = "🍀", Goal = 250, Gems = 15, Value = stat("OrbsCollected") },
	{
		Id = "Orbs3",
		Text = "Pick up %s clovers",
		Icon = "🍀",
		Goal = 1_000,
		Gems = 40,
		Value = stat("OrbsCollected"),
	},
	{
		Id = "Orbs4",
		Text = "Pick up %s clovers",
		Icon = "🍀",
		Goal = 5_000,
		Gems = 100,
		Value = stat("OrbsCollected"),
	},

	{ Id = "Rebirths1", Text = "Rebirth %s times", Icon = "🔁", Goal = 1, Gems = 20, Value = field("Rebirths") },
	{ Id = "Rebirths2", Text = "Rebirth %s times", Icon = "🔁", Goal = 5, Gems = 60, Value = field("Rebirths") },
	{ Id = "Rebirths3", Text = "Rebirth %s times", Icon = "🔁", Goal = 15, Gems = 150, Value = field("Rebirths") },
	{ Id = "Rebirths4", Text = "Rebirth %s times", Icon = "🔁", Goal = 30, Gems = 350, Value = field("Rebirths") },

	{ Id = "Zones1", Text = "Reach area %s", Icon = "🗺️", Goal = 3, Gems = 25, Value = field("HighestZone") },
	{
		Id = "Zones2",
		Text = "Reach area %s",
		Icon = "🗺️",
		Goal = #Zones.List,
		Gems = 60,
		Value = field("HighestZone"),
	},

	{ Id = "Index1", Text = "Discover %s different pets", Icon = "📖", Goal = 10, Gems = 15, Value = petsDiscovered },
	{ Id = "Index2", Text = "Discover %s different pets", Icon = "📖", Goal = 20, Gems = 40, Value = petsDiscovered },
	{
		Id = "Index3",
		Text = "Discover %s different pets",
		Icon = "📖",
		Goal = totalPets,
		Gems = 100,
		Value = petsDiscovered,
	},
}

local ById: { [string]: Template } = {}
for _, template in Templates do
	ById[template.Id] = template
end

local Achievements = {
	Templates = Templates,
	ById = ById,
}

function Achievements.progress(data, template: Template): number
	return math.clamp(template.Value(data), 0, template.Goal)
end

function Achievements.isClaimed(data, template: Template): boolean
	return data.Achievements[template.Id] == true
end

return Achievements
