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

function RebirthWindow.build()
	local body = Windows.create("Rebirth", "🔁 Rebirth", Theme.Colors.Rebirth, Vector2.new(500, 410))

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
		Text = "Resets your coins and Tap Power.\nKeeps pets, areas, gems and every other upgrade.",
		TextColor3 = Theme.Colors.SubText,
		Parent = body,
	})
	local button = Util.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(280, 70),
		Text = "REBIRTH!",
		Parent = body,
	}, function()
		Actions("Rebirth")
	end)

	State.watch({ "Coins", "Rebirths" }, function()
		local data = State.Data
		local cost = Formula.rebirthCost(data.Rebirths)
		count.Text = "Rebirths: " .. data.Rebirths
		multiplier.Text = string.format(
			"Coins %s  →  %s",
			Format.multiplier(Formula.rebirthMultiplier(data.Rebirths)),
			Format.multiplier(Formula.rebirthMultiplier(data.Rebirths + 1))
		)
		reward.Text = "Reward: 💎 " .. Formula.rebirthGems(data.Rebirths)
		setProgress(data.Coins / cost, "🪙 " .. Format.number(data.Coins) .. " / " .. Format.number(cost))
		local ready = data.Coins >= cost
		button.BackgroundColor3 = if ready then Theme.Colors.Green else Theme.Colors.Disabled
		button.Text = if ready then "REBIRTH!" else "Need 🪙 " .. Format.number(cost - data.Coins)
	end)
end

return RebirthWindow
