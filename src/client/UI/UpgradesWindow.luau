local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Formula = require(Shared.Formula)
local Upgrades = require(Shared.Upgrades)

local Actions = require(script.Parent.Parent.Actions)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Windows = require(script.Parent.Windows)

local UpgradesWindow = {}

type Row = { Upgrade: Upgrades.Upgrade, Title: TextLabel, Effect: TextLabel, Buy: TextButton }

function UpgradesWindow.build()
	local body = Windows.create("Upgrades", "⬆️ Upgrades", Theme.Colors.Blue, Vector2.new(620, 480))
	local list = Util.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	}, { Util.list(Enum.FillDirection.Vertical, 8) })

	local rows: { Row } = {}
	local order = 0
	local lastCurrency = nil
	for _, upgrade in Upgrades.List do
		if upgrade.Currency ~= lastCurrency then
			lastCurrency = upgrade.Currency
			order += 1
			Util.label({
				LayoutOrder = order,
				Size = UDim2.new(1, -12, 0, 30),
				Text = if upgrade.Currency == "Coins" then "🪙 Coin Upgrades" else "💎 Gem Upgrades (kept forever)",
				TextColor3 = if upgrade.Currency == "Coins" then Theme.Colors.Coins else Theme.Colors.Gems,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = list,
			})
		end
		order += 1
		local row = Util.new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, 78),
			BackgroundColor3 = Theme.Colors.Panel,
			Parent = list,
		}, { Util.corner(14) })
		Util.label({
			Size = UDim2.fromOffset(56, 56),
			Position = UDim2.fromOffset(10, 11),
			Text = upgrade.Icon,
			Parent = row,
		})
		local title = Util.label({
			Size = UDim2.new(1, -250, 0, 28),
			Position = UDim2.fromOffset(76, 6),
			Text = upgrade.Name,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Util.label({
			Size = UDim2.new(1, -250, 0, 18),
			Position = UDim2.fromOffset(76, 34),
			Text = upgrade.Description,
			TextColor3 = Theme.Colors.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local effect = Util.label({
			Size = UDim2.new(1, -250, 0, 18),
			Position = UDim2.fromOffset(76, 54),
			Text = "",
			TextColor3 = Theme.Colors.Green,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local buy = Util.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(150, 54),
			Parent = row,
		}, function()
			Actions("BuyUpgrade", upgrade.Id)
		end)
		table.insert(rows, { Upgrade = upgrade, Title = title, Effect = effect, Buy = buy })
	end

	State.watch({ "Coins", "Gems", "Upgrades" }, function()
		local data = State.Data
		for _, row in rows do
			local upgrade = row.Upgrade
			local level = Formula.level(data, upgrade.Id)
			local cost = Formula.upgradeCost(upgrade.Id, level)
			row.Title.Text = string.format("%s  ·  Lv %d/%d", upgrade.Name, level, upgrade.MaxLevel)
			if cost then
				row.Effect.Text = Formula.upgradeEffect(upgrade.Id, level)
					.. "  →  "
					.. Formula.upgradeEffect(upgrade.Id, level + 1)
				local icon = if upgrade.Currency == "Coins" then "🪙 " else "💎 "
				row.Buy.Text = icon .. Format.number(cost)
				local affordable = data[upgrade.Currency] >= cost
				row.Buy.BackgroundColor3 = if affordable then Theme.Colors.Green else Theme.Colors.Disabled
			else
				row.Effect.Text = Formula.upgradeEffect(upgrade.Id, level)
				row.Buy.Text = "MAX"
				row.Buy.BackgroundColor3 = Theme.Colors.Gold
			end
		end
	end)
end

return UpgradesWindow
