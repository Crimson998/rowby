local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared.Achievements)
local Format = require(Shared.Format)

local Actions = require(script.Parent.Parent.Actions)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Windows = require(script.Parent.Windows)

local AchievementsWindow = {}

function AchievementsWindow.build()
	local body = Windows.create("Achievements", "🏆 Achievements", Theme.Colors.Teal, Vector2.new(620, 460))

	local header = Util.label({
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		TextColor3 = Theme.Colors.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = body,
	})

	local list = Util.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	}, { Util.list(Enum.FillDirection.Vertical, 8) })

	local rows = {}
	for order, template in Achievements.Templates do
		local row = Util.new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 78),
			BackgroundColor3 = Theme.Colors.Panel,
			Parent = list,
		}, { Util.corner(14) })
		Util.label({
			Size = UDim2.fromOffset(52, 52),
			Position = UDim2.fromOffset(10, 13),
			Text = template.Icon,
			Parent = row,
		})
		Util.label({
			Size = UDim2.new(1, -220, 0, 26),
			Position = UDim2.fromOffset(72, 8),
			Text = string.format(template.Text, Format.number(template.Goal)),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local _, setProgress = Util.bar({
			Size = UDim2.new(1, -220, 0, 24),
			Position = UDim2.fromOffset(72, 40),
			Color = Theme.Colors.Teal,
			Parent = row,
		})
		local claim = Util.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(130, 56),
			Parent = row,
		}, function()
			Actions("ClaimAchievement", template.Id)
		end)
		rows[template.Id] = { Row = row, SetProgress = setProgress, Claim = claim }
	end

	State.watch({ "Achievements", "Stats", "Rebirths", "HighestZone", "Index" }, function()
		local data = State.Data
		local claimedCount = 0
		for _, template in Achievements.Templates do
			local row = rows[template.Id]
			local claimed = Achievements.isClaimed(data, template)
			if claimed then
				claimedCount += 1
			end
			local progress = Achievements.progress(data, template)
			row.SetProgress(progress / template.Goal, Format.number(progress) .. " / " .. Format.number(template.Goal))
			local done = progress >= template.Goal
			row.Row.BackgroundColor3 = if claimed then Theme.Colors.PanelLight else Theme.Colors.Panel
			row.Claim.Text = if claimed
				then "✅ Done"
				elseif done then "Claim 💎" .. template.Gems
				else "💎 " .. template.Gems
			row.Claim.BackgroundColor3 = if claimed or not done then Theme.Colors.Disabled else Theme.Colors.Green
		end
		header.Text = "Claimed: " .. claimedCount .. " / " .. #Achievements.Templates
	end)
end

return AchievementsWindow
