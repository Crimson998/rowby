--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Formula = require(Shared.Formula)

local Actions = require(script.Parent.Parent.Actions)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Windows = require(script.Parent.Windows)

local RebirthWindow = {}

local NAME = "Rebirth"
-- How long the "tap again to confirm" step stays armed.
local CONFIRM_SECONDS = 4

function RebirthWindow.build()
	local body = Windows.create(NAME, "🔁 Rebirth", Theme.Colors.Rebirth, Vector2.new(500, 500))

	local count = Util.label({ Size = UDim2.new(1, 0, 0, 30), Text = "", Parent = body })
	local multiplier = Util.label({
		Size = UDim2.new(1, 0, 0, 52),
		Position = UDim2.fromOffset(0, 36),
		Text = "",
		TextColor3 = Theme.Colors.Rebirth,
		Parent = body,
	})
	local reward = Util.label({
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 94),
		Text = "",
		TextColor3 = Theme.Colors.Gems,
		Parent = body,
	})
	local _, setProgress = Util.bar({
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 132),
		Color = Theme.Colors.Rebirth,
		Parent = body,
	})
	Util.label({
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 176),
		Text = "Resets your coins, Tap Power and Luck level.\nKeeps pets, areas, gems, shop perks and every other upgrade.\nEach rebirth raises your Luck level cap.",
		TextColor3 = Theme.Colors.SubText,
		Parent = body,
	})
	Util.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 226),
		Size = UDim2.fromOffset(280, 40),
		Text = "🛒 Rebirth Shop",
		Color = Theme.Colors.Blue,
		Parent = body,
	}, function()
		Windows.open("RebirthShop")
	end)
	-- Rebirth resets your Luck level, so it takes two taps: the first arms it and shows what
	-- you'll lose, the second (within CONFIRM_SECONDS) rebirths.
	local warning = Util.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -78),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		TextColor3 = Theme.Colors.Orange,
		Visible = false,
		Parent = body,
	})
	local armed = false
	local armToken = 0
	local refresh: () -> ()

	local function disarm()
		armed = false
		armToken += 1
	end

	local button = Util.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(280, 70),
		Text = "REBIRTH!",
		Parent = body,
	}, function()
		local data = State.Data
		if data.Coins < Formula.rebirthCost(data.Rebirths) then
			Actions("Rebirth") -- the server explains how many coins are still needed
			return
		end
		if armed then
			disarm()
			Actions("Rebirth")
		else
			armed = true
			armToken += 1
			local token = armToken
			task.delay(CONFIRM_SECONDS, function()
				if armToken == token then
					disarm()
					refresh()
				end
			end)
		end
		refresh()
	end)

	function refresh()
		local data = State.Data
		local cost = Formula.rebirthCost(data.Rebirths)
		count.Text = "Rebirths: " .. data.Rebirths
		multiplier.Text = string.format(
			"Coins %s  →  %s",
			Format.multiplier(Formula.rebirthMultiplier(data.Rebirths)),
			Format.multiplier(Formula.rebirthMultiplier(data.Rebirths + 1))
		)
		reward.Text = "Reward: 💎 "
			.. Formula.nextRebirthGems(data)
			.. "  ·  🍀 Luck cap Lv "
			.. Formula.luckCap(data.Rebirths)
			.. " → "
			.. Formula.luckCap(data.Rebirths + 1)
		setProgress(data.Coins / cost, "🪙 " .. Format.number(data.Coins) .. " / " .. Format.number(cost))
		local ready = data.Coins >= cost
		if armed and not ready then
			disarm()
		end
		warning.Visible = armed
		warning.Text = "⚠️ Your Luck level (Lv " .. Formula.luckLevelOf(data) .. ") goes back to 0"
		if armed then
			button.BackgroundColor3 = Theme.Colors.Orange
			button.Text = "Tap again to rebirth"
		else
			button.BackgroundColor3 = if ready then Theme.Colors.Green else Theme.Colors.Disabled
			button.Text = if ready then "REBIRTH!" else "Need 🪙 " .. Format.number(cost - data.Coins)
		end
	end

	State.watch({ "Coins", "Rebirths", "LuckXP", "RebirthPerks" }, refresh)
	-- Opening the window always starts unarmed.
	Windows.onOpen(NAME, function()
		disarm()
		refresh()
	end)
end

return RebirthWindow
