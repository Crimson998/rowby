--!strict
--[[
	The first-session tutorial: short prompts that walk a new player through tapping, hatching,
	checking their team, grabbing a clover and opening Upgrades. Progress is worked out from the
	profile (stats) plus the windows the player has opened this session, so nothing extra is saved
	except Settings.TutorialDone once it is finished or skipped.
]]

export type Step = {
	Id: string,
	Text: string,
	-- Windows the player must have opened this session (by Windows name), if any.
	Window: string?,
	-- True once the profile shows the step is already done.
	Done: (data: any) -> boolean,
}

local Tutorial = {}

Tutorial.TapsNeeded = 5

Tutorial.Steps = {
	{
		Id = "Tap",
		Text = "👆 Tap the big TAP button to earn coins!",
		Done = function(data)
			return data.Stats.Taps >= Tutorial.TapsNeeded
		end,
	},
	{
		Id = "Hatch",
		Text = "🥚 Follow the green beam to the egg and hatch your first pet!",
		Done = function(data)
			return data.Stats.EggsHatched >= 1
		end,
	},
	{
		Id = "Team",
		Text = "🐾 Open Pets to see your team. Your best pets are equipped for you.",
		Window = "Pets",
		Done = function()
			return false
		end,
	},
	{
		Id = "Clover",
		Text = "🍀 Grab a floating clover to earn Luck XP and better hatches!",
		Done = function(data)
			return data.Stats.OrbsCollected >= 1
		end,
	},
	{
		Id = "Upgrades",
		Text = "⬆️ Open Upgrades to spend coins on stronger taps, luck and more.",
		Window = "Upgrades",
		Done = function()
			return false
		end,
	},
} :: { Step }

-- Players who already hatched this many eggs know the game; they never see the tutorial.
Tutorial.VeteranHatches = 10

function Tutorial.isVeteran(data: any): boolean
	return data.Stats.EggsHatched >= Tutorial.VeteranHatches
end

-- Index of the first unfinished step, or nil when every step is done.
function Tutorial.current(data: any, opened: { [string]: boolean }): number?
	for index, step in Tutorial.Steps do
		local windowDone = step.Window ~= nil and opened[step.Window] == true
		if not (windowDone or step.Done(data)) then
			return index
		end
	end
	return nil
end

return Tutorial
