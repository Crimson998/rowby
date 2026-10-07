local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formula = require(Shared.Formula)
local RebirthPerks = require(Shared.RebirthPerks)

local Actions = require(script.Parent.Parent.Actions)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Windows = require(script.Parent.Windows)

local RebirthShopWindow = {}

type Row = { Perk: RebirthPerks.Perk, Title: TextLabel, Effect: TextLabel, Buy: TextButton }

function RebirthShopWindow.build()
	local body = Windows.create("RebirthShop", "🛒 Rebirth Shop", Theme.Colors.Rebirth, Vector2.new(560, 440))
	local tokens = Util.label({
		Size = UDim2.new(1, 0, 0, 30),
		Text = "",
		TextColor3 = Theme.Colors.Rebirth,
		Parent = body,
	})
	Util.label({
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 32),
		Text = "Every rebirth earns 1 token. Perks are permanent and survive rebirthing.",
		TextColor3 = Theme.Colors.SubText,
		Parent = body,
	})
	local list = Util.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 1, -62),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	}, { Util.list(Enum.FillDirection.Vertical, 8) })

	local rows: { Row } = {}
	for index, perk in RebirthPerks.List do
		local row = Util.new("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, -12, 0, 78),
			BackgroundColor3 = Theme.Colors.Panel,
			Parent = list,
		}, { Util.corner(14) })
		Util.label({
			Size = UDim2.fromOffset(56, 56),
			Position = UDim2.fromOffset(10, 11),
			Text = perk.Icon,
			Parent = row,
		})
		local title = Util.label({
			Size = UDim2.new(1, -190, 0, 28),
			Position = UDim2.fromOffset(76, 6),
			Text = perk.Name,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Util.label({
			Size = UDim2.new(1, -190, 0, 18),
			Position = UDim2.fromOffset(76, 34),
			Text = perk.Description,
			TextColor3 = Theme.Colors.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local effect = Util.label({
			Size = UDim2.new(1, -190, 0, 18),
			Position = UDim2.fromOffset(76, 54),
			Text = "",
			TextColor3 = Theme.Colors.Green,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local buy = Util.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(118, 54),
			Parent = row,
		}, function()
			Actions("BuyRebirthPerk", perk.Id)
		end)
		table.insert(rows, { Perk = perk, Title = title, Effect = effect, Buy = buy })
	end

	State.watch({ "Rebirths", "RebirthPerks" }, function()
		local data = State.Data
		local available = Formula.rebirthTokens(data)
		tokens.Text = "🔁 Rebirth Tokens: " .. available
		for _, row in rows do
			local id = row.Perk.Id
			local level = Formula.perkLevel(data, id)
			local cost = Formula.perkCost(id, level)
			row.Title.Text = string.format("%s  ·  Lv %d/%d", row.Perk.Name, level, #row.Perk.Costs)
			if cost then
				row.Effect.Text = Formula.perkEffect(id, level) .. "  →  " .. Formula.perkEffect(id, level + 1)
				row.Buy.Text = "🔁 " .. cost
				row.Buy.BackgroundColor3 = if available >= cost then Theme.Colors.Green else Theme.Colors.Disabled
			else
				row.Effect.Text = Formula.perkEffect(id, level)
				row.Buy.Text = "MAXED"
				row.Buy.BackgroundColor3 = Theme.Colors.Gold
			end
		end
	end)
end

return RebirthShopWindow
