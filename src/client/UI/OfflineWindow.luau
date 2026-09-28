--[[
	💤 Offline earnings: coins your pets earned while you were away (Config.Offline), waiting to
	be collected. Opens by itself when you join with coins waiting; otherwise it explains how
	offline earnings work and what a full stretch away would earn right now.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Formula = require(Shared.Formula)

local Actions = require(script.Parent.Parent.Actions)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Windows = require(script.Parent.Windows)

local OfflineWindow = {}

local NAME = "Offline"

function OfflineWindow.build()
	local body = Windows.create(NAME, "💤 Offline Earnings", Theme.Colors.Purple, Vector2.new(520, 420))

	local panel = Util.new("Frame", {
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundColor3 = Theme.Colors.Panel,
		Parent = body,
	}, { Util.corner(14) })
	local away = Util.label({
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(12, 12),
		Text = "",
		TextColor3 = Theme.Colors.SubText,
		Parent = panel,
	})
	local amount = Util.label({
		Size = UDim2.new(1, -24, 0, 60),
		Position = UDim2.fromOffset(12, 44),
		Text = "",
		TextColor3 = Theme.Colors.Coins,
		Parent = panel,
	})
	local note = Util.label({
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(12, 112),
		Text = "",
		TextColor3 = Theme.Colors.SubText,
		Parent = panel,
	})

	local function infoLine(order: number): TextLabel
		return Util.label({
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.fromOffset(4, 160 + (order - 1) * 26),
			Text = "",
			TextColor3 = Theme.Colors.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = body,
		})
	end
	local offline = Config.Offline
	infoLine(1).Text = string.format(
		"• Your pets earn %d%% of your normal coin rate while you're away",
		math.floor(offline.Rate * 100 + 0.5)
	)
	infoLine(2).Text = string.format(
		"• Counts up to %s away, starting after %s",
		Format.duration(offline.MaxHours * 3600),
		Format.duration(offline.MinSeconds)
	)
	local estimate = infoLine(3)

	local collect = Util.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(300, 56),
		Parent = body,
	}, function()
		Actions("ClaimOffline")
	end)

	-- Opens by itself once per session when coins are waiting. The server adds them just after
	-- your data first arrives, so this happens on the change rather than at build time.
	local greeted = false

	local function refresh()
		local data, session = State.Data, State.Session
		local waiting = data.Offline or { Coins = 0, Away = 0 }
		local most = Formula.offlineCoins(data, session, math.huge)
		if waiting.Coins > 0 then
			away.Text = "Welcome back! You were away for " .. Format.duration(waiting.Away)
			amount.Text = "🪙 " .. Format.number(waiting.Coins)
			note.Text = if waiting.Away > offline.MaxHours * 3600
				then "Only the first " .. Format.duration(offline.MaxHours * 3600) .. " count"
				else "Earned by your pets while you were gone"
			collect.Text = "Collect 🪙 " .. Format.number(waiting.Coins)
			collect.BackgroundColor3 = Theme.Colors.Green
			if not greeted then
				greeted = true
				Windows.open(NAME)
			end
		else
			away.Text = "Nothing to collect right now"
			amount.Text = "🪙 0"
			note.Text = "Come back after a break and your pets will have earned coins"
			collect.Text = "Nothing to collect"
			collect.BackgroundColor3 = Theme.Colors.Disabled
		end
		estimate.Text = string.format(
			"• A full %s away would earn about 🪙 %s right now",
			Format.duration(offline.MaxHours * 3600),
			Format.number(most)
		)
	end

	State.watch({ "Offline", "Upgrades", "Pets", "Index", "Rebirths", "HighestZone", "Session.Passes" }, refresh)
end

return OfflineWindow
