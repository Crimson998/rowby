local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Formula = require(Shared.Formula)
local Rewards = require(Shared.Rewards)

local Actions = require(script.Parent.Parent.Actions)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Windows = require(script.Parent.Windows)

local DailyWindow = {}

local NAME = "Daily"

function DailyWindow.build()
	local body = Windows.create(NAME, "📅 Daily Rewards", Theme.Colors.Red, Vector2.new(700, 360))

	local row = Util.new("Frame", {
		Size = UDim2.new(1, 0, 0, 170),
		BackgroundTransparency = 1,
		Parent = body,
	}, { Util.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center) })

	local tiles = {}
	for day, reward in Config.Daily.Rewards do
		local tile = Util.new("Frame", {
			LayoutOrder = day,
			Size = UDim2.fromOffset(86, 170),
			BackgroundColor3 = Theme.Colors.Panel,
			Parent = row,
		}, { Util.corner(14), Util.stroke(nil, 3) })
		Util.label({
			Size = UDim2.new(1, -8, 0, 26),
			Position = UDim2.fromOffset(4, 6),
			Text = "Day " .. day,
			Parent = tile,
		})
		local parts = Rewards.parts(reward)
		for index, part in parts do
			Util.label({
				Size = UDim2.new(1, -8, 0, 20),
				Position = UDim2.fromOffset(4, 36 + (index - 1) * 24),
				Text = part,
				TextColor3 = Theme.Colors.SubText,
				Parent = tile,
			})
		end
		local status = Util.label({
			AnchorPoint = Vector2.new(0, 1),
			Size = UDim2.new(1, -8, 0, 26),
			Position = UDim2.new(0, 4, 1, -6),
			Text = "",
			Parent = tile,
		})
		tiles[day] = { Frame = tile, Status = status }
	end

	Util.label({
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 180),
		Text = "Come back every day for bigger rewards! Missing a day restarts at Day 1.",
		TextColor3 = Theme.Colors.SubText,
		Parent = body,
	})

	local claim = Util.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(320, 60),
		Parent = body,
	}, function()
		Actions("ClaimDaily")
	end)

	local function refresh()
		local canClaim, day, remaining, streak = Formula.dailyStatus(State.Data.Daily, workspace:GetServerTimeNow())
		local total = #Config.Daily.Rewards
		-- Days already claimed in the current 7-day cycle.
		local claimed = if canClaim then streak % total else ((streak - 1) % total) + 1
		for index, tile in tiles do
			local stroke = tile.Frame:FindFirstChild("Border") :: UIStroke
			if index <= claimed then
				tile.Status.Text = "✅"
				tile.Frame.BackgroundColor3 = Theme.Colors.PanelLight
				stroke.Color = Theme.Colors.Stroke
			elseif canClaim and index == day then
				tile.Status.Text = "TODAY!"
				tile.Frame.BackgroundColor3 = Theme.Colors.Green
				stroke.Color = Theme.Colors.Gold
			else
				tile.Status.Text = ""
				tile.Frame.BackgroundColor3 = Theme.Colors.Panel
				stroke.Color = Theme.Colors.Stroke
			end
		end
		if canClaim then
			claim.Text = "Claim Day " .. day .. "!"
			claim.BackgroundColor3 = Theme.Colors.Green
		else
			claim.Text = "Next reward in " .. Format.time(remaining)
			claim.BackgroundColor3 = Theme.Colors.Disabled
		end
	end

	State.watch({ "Daily" }, refresh)
	task.spawn(function()
		while true do
			task.wait(1)
			if Windows.isOpen(NAME) then
				refresh()
			end
		end
	end)
end

return DailyWindow
