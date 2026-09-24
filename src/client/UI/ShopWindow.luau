--[[
	Robux shop. Prices and what you get are always shown before the purchase prompt.
	Items tied to random pets are hidden where paid random items are restricted.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formula = require(Shared.Formula)
local Format = require(Shared.Format)
local Products = require(Shared.Products)

local Actions = require(script.Parent.Parent.Actions)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Windows = require(script.Parent.Windows)

local ShopWindow = {}

local NAME = "Shop"
local TABS = { "Featured", "Passes", "Boosts", "Coins", "Gems" }
local FEATURED_PASSES = { "VIP", "DoubleCoins", "AutoTap" }

local currentTab = "Featured"
local grid: ScrollingFrame
local note: TextLabel
local tabButtons: { [string]: TextButton } = {}

type Item = {
	Kind: string,
	Key: string,
	Name: string,
	Icon: string,
	Price: number,
	Description: string,
	Tag: string?,
	RandomItemRelated: boolean?,
	Reward: Products.Reward?,
}

local function itemsFor(tab: string): { Item }
	local items: { Item } = {}
	local function addPass(pass: Products.GamePass)
		table.insert(items, {
			Kind = "Pass",
			Key = pass.Key,
			Name = pass.Name,
			Icon = pass.Icon,
			Price = pass.Price,
			Description = pass.Description,
			RandomItemRelated = pass.RandomItemRelated,
		})
	end
	local function addProduct(product: Products.DevProduct)
		table.insert(items, {
			Kind = "Product",
			Key = product.Key,
			Name = product.Name,
			Icon = product.Icon,
			Price = product.Price,
			Description = product.Description,
			Tag = product.Tag,
			RandomItemRelated = product.RandomItemRelated,
			Reward = product.Reward,
		})
	end
	if tab == "Featured" then
		for _, product in Products.DevProducts do
			if product.Category == "Featured" and not State.Data.OneTime[product.Key] then
				addProduct(product)
			end
		end
		for _, key in FEATURED_PASSES do
			addPass(Products.PassByKey[key])
		end
	elseif tab == "Passes" then
		for _, pass in Products.GamePasses do
			addPass(pass)
		end
	else
		for _, product in Products.DevProducts do
			if product.Category == tab then
				addProduct(product)
			end
		end
	end
	return items
end

local function rebuild()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for tab, button in tabButtons do
		button.BackgroundColor3 = if tab == currentTab then Theme.Colors.Green else Theme.Colors.PanelLight
	end

	local restricted = State.Session.RandomItemsRestricted == true
	local hidden = 0
	for order, item in itemsFor(currentTab) do
		if item.RandomItemRelated and restricted then
			hidden += 1
			continue
		end
		local owned = item.Kind == "Pass" and State.Session.Passes[item.Key] == true
		local cardFrame = Util.new("Frame", {
			LayoutOrder = order,
			BackgroundColor3 = Theme.Colors.Panel,
			Parent = grid,
		}, { Util.corner(16), Util.stroke(nil, 3) })
		Util.label({
			Size = UDim2.new(1, 0, 0, 44),
			Position = UDim2.fromOffset(0, 6),
			Text = item.Icon,
			Parent = cardFrame,
		})
		Util.label({
			Size = UDim2.new(1, -16, 0, 24),
			Position = UDim2.fromOffset(8, 50),
			Text = item.Name,
			Parent = cardFrame,
		})
		local description = item.Description
		if item.Reward and item.Reward.CoinSeconds then
			local coins = Formula.rewardCoins(State.Data, State.Session, item.Reward.CoinSeconds)
			description = "🪙 " .. Format.number(coins) .. " coins — " .. description
		end
		Util.label({
			Size = UDim2.new(1, -16, 0, 50),
			Position = UDim2.fromOffset(8, 76),
			Text = description,
			TextColor3 = Theme.Colors.SubText,
			TextWrapped = true,
			Parent = cardFrame,
		})
		if item.Tag then
			local ribbon = Util.label({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 6, 0, -6),
				Size = UDim2.fromOffset(96, 24),
				BackgroundTransparency = 0,
				BackgroundColor3 = Theme.Colors.Red,
				Text = item.Tag,
				Rotation = 8,
				Parent = cardFrame,
			})
			Util.corner(8).Parent = ribbon
		end
		Util.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -24, 0, 40),
			Text = if owned then "Owned ✓" else "R$ " .. item.Price,
			Color = if owned then Theme.Colors.Disabled else Theme.Colors.Green,
			Parent = cardFrame,
		}, function()
			if owned then
				return
			end
			Actions(if item.Kind == "Pass" then "BuyPass" else "BuyProduct", item.Key)
		end)
	end
	note.Visible = hidden > 0
end

function ShopWindow.open(tab: string?)
	if tab and table.find(TABS, tab) then
		currentTab = tab
	end
	if Windows.isOpen(NAME) then
		rebuild()
	else
		Windows.open(NAME)
	end
end

function ShopWindow.build()
	local body = Windows.create(NAME, "🛒 Shop", Theme.Colors.Green, Vector2.new(760, 490))

	local tabs = Util.new("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = body,
	}, { Util.list(Enum.FillDirection.Horizontal, 8) })
	for order, tab in TABS do
		tabButtons[tab] = Util.button({
			LayoutOrder = order,
			Text = tab,
			Size = UDim2.fromOffset(120, 38),
			Color = Theme.Colors.PanelLight,
			Parent = tabs,
		}, function()
			currentTab = tab
			rebuild()
		end)
	end

	grid = Util.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -76),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	}, {
		Util.padding(8),
		Util.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(222, 190),
			CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	note = Util.label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "Some items aren't available in your region.",
		TextColor3 = Theme.Colors.SubText,
		Visible = false,
		Parent = body,
	})

	State.watch({ "OneTime", "Session.Passes", "Session.RandomItemsRestricted" }, function()
		if Windows.isOpen(NAME) then
			rebuild()
		end
	end)
	Windows.onOpen(NAME, rebuild)
end

return ShopWindow
