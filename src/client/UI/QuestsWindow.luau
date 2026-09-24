local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Quests = require(Shared.Quests)

local Actions = require(script.Parent.Parent.Actions)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Windows = require(script.Parent.Windows)

local QuestsWindow = {}

function QuestsWindow.build()
	local body = Windows.create("Quests", "📜 Quests", Theme.Colors.Purple, Vector2.new(560, 400))

	local rows = {}
	for slot = 1, Quests.Slots do
		local row = Util.new("Frame", {
			Size = UDim2.new(1, 0, 0, 86),
			Position = UDim2.fromOffset(0, (slot - 1) * 96),
			BackgroundColor3 = Theme.Colors.Panel,
			Parent = body,
		}, { Util.corner(14) })
		local icon = Util.label({
			Size = UDim2.fromOffset(56, 56),
			Position = UDim2.fromOffset(10, 15),
			Text = "",
			Parent = row,
		})
		local text = Util.label({
			Size = UDim2.new(1, -230, 0, 28),
			Position = UDim2.fromOffset(76, 10),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local _, setProgress = Util.bar({
			Size = UDim2.new(1, -230, 0, 26),
			Position = UDim2.fromOffset(76, 46),
			Color = Theme.Colors.Purple,
			Parent = row,
		})
		local claim = Util.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(130, 56),
			Parent = row,
		}, function()
			Actions("ClaimQuest", slot)
		end)
		rows[slot] = { Icon = icon, Text = text, SetProgress = setProgress, Claim = claim }
	end

	local footer = Util.label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		TextColor3 = Theme.Colors.SubText,
		Parent = body,
	})

	State.watch({ "Quests", "Stats", "QuestsCompleted" }, function()
		local data = State.Data
		for slot, row in rows do
			local quest = data.Quests[slot]
			if not quest then
				continue
			end
			local template = Quests.ByStat[quest.Stat]
			local progress = Quests.progress(data, quest)
			row.Icon.Text = template.Icon
			row.Text.Text = string.format(template.Text, Format.number(quest.Goal))
			row.SetProgress(progress / quest.Goal, Format.number(progress) .. " / " .. Format.number(quest.Goal))
			local done = progress >= quest.Goal
			row.Claim.Text = if done then "Claim 💎" .. quest.Gems else "💎 " .. quest.Gems
			row.Claim.BackgroundColor3 = if done then Theme.Colors.Green else Theme.Colors.Disabled
		end
		footer.Text = "Quests completed: " .. data.QuestsCompleted .. "  ·  New quests appear as you finish them!"
	end)
end

return QuestsWindow
