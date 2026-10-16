--[[
	First-session tutorial prompt: a small banner under the top of the screen showing the next
	step from Tutorial.luau, with a Skip button. Hidden once the tutorial is finished or skipped
	(Settings.TutorialDone) and never shown to players with real progress.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tutorial = require(ReplicatedStorage:WaitForChild("Shared").Tutorial)

local Actions = require(script.Parent.Parent.Actions)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Windows = require(script.Parent.Windows)

local TutorialPrompt = {}

local WATCHED = { "Pets", "Upgrades" }

function TutorialPrompt.build(screen: ScreenGui)
	local opened: { [string]: boolean } = {}
	local finished = false

	local frame = Util.new("Frame", {
		Name = "TutorialPrompt",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(560, 56),
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		ZIndex = 6,
		Parent = screen,
	}, { Util.corner(16), Util.stroke(Theme.Colors.Gold, 3) })
	Util.autoScale(frame)

	local text = Util.label({
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -110, 1, -12),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = frame,
	})
	Util.button({
		Text = "Skip",
		Color = Theme.Colors.Gray,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(80, 36),
		ZIndex = 7,
		Parent = frame,
	}, function()
		Actions("SetSetting", "TutorialDone", true)
	end)

	local function refresh()
		if finished then
			return
		end
		if State.Data.Settings.TutorialDone then
			finished = true
			frame.Visible = false
			return
		end
		if Tutorial.isVeteran(State.Data) then
			finished = true
			frame.Visible = false
			Actions("SetSetting", "TutorialDone", true)
			return
		end
		local index = Tutorial.current(State.Data, opened)
		if index == nil then
			finished = true
			frame.Visible = false
			Actions("SetSetting", "TutorialDone", true)
			Notifications.banner("🎉 You're ready to play!", nil, 3)
			return
		end
		local step = Tutorial.Steps[index]
		text.Text = string.format("(%d/%d) %s", index, #Tutorial.Steps, step.Text)
		frame.Visible = true
	end

	for _, name in WATCHED do
		Windows.onOpen(name, function()
			opened[name] = true
			refresh()
		end)
	end
	State.watch({ "Stats", "Settings" }, refresh)
end

return TutorialPrompt
