--[[
	Always-on screen elements: currencies, menu buttons with alert badges, the next-goal tracker,
	active boosts, the big TAP button, auto-tap toggle, free-gift timer and starter pack.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Eggs = require(Shared.Eggs)
local Format = require(Shared.Format)
local Formula = require(Shared.Formula)
local Products = require(Shared.Products)
local Quests = require(Shared.Quests)
local Zones = require(Shared.Zones)

local Actions = require(script.Parent.Parent.Actions)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Windows = require(script.Parent.Windows)

local Hud = {}

-- The frame around the TAP button, so other controllers can place buttons beside it.
Hud.TapArea = nil :: Frame?

local tapButton: TextButton
local tapValueLabel: TextLabel
local badges: { [string]: Frame } = {}
local onTap: (() -> ())? = nil

local MENU = {
	{ Window = "Pets", Icon = "🐾", Color = Theme.Colors.Orange },
	{ Window = "Upgrades", Icon = "⬆️", Color = Theme.Colors.Blue },
	{ Window = "Rebirth", Icon = "🔁", Color = Theme.Colors.Rebirth },
	{ Window = "Shop", Icon = "🛒", Color = Theme.Colors.Green },
	{ Window = "Quests", Icon = "📜", Color = Theme.Colors.Purple },
	{ Window = "Daily", Icon = "📅", Color = Theme.Colors.Red },
	{ Window = "Gifts", Icon = "🎁", Color = Theme.Colors.Gold },
	{ Window = "Stats", Icon = "📊", Color = Theme.Colors.Luck },
	{ Window = "Codes", Icon = "🎫", Color = Theme.Colors.Gray },
	{ Window = "Settings", Icon = "⚙️", Color = Theme.Colors.Gray },
}

local function buildCurrencies(screen: ScreenGui, openShop: (string) -> ())
	local panel = Util.new("Frame", {
		Name = "Currencies",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(240, 210),
		BackgroundTransparency = 1,
		Parent = screen,
	}, { Util.list(Enum.FillDirection.Vertical, 8) })
	Util.autoScale(panel)

	local function pill(order: number, icon: string, color: Color3, shopTab: string?): TextLabel
		local frame = Util.new("Frame", {
			LayoutOrder = order,
			Size = UDim2.fromOffset(240, 44),
			BackgroundColor3 = Theme.Colors.Panel,
			Parent = panel,
		}, { Util.corner(22), Util.stroke(nil, 3) })
		Util.label({ Size = UDim2.fromOffset(38, 34), Position = UDim2.fromOffset(6, 5), Text = icon, Parent = frame })
		local amount = Util.label({
			Size = UDim2.new(1, if shopTab then -96 else -56, 0, 30),
			Position = UDim2.fromOffset(48, 7),
			Text = "0",
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		if shopTab then
			Util.button({
				Text = "+",
				Color = Theme.Colors.Green,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -5, 0.5, 0),
				Size = UDim2.fromOffset(36, 34),
				CornerRadius = 17,
				Parent = frame,
			}, function()
				openShop(shopTab)
			end)
		end
		return amount
	end

	local coins = pill(1, "🪙", Theme.Colors.Coins, "Coins")
	local gems = pill(2, "💎", Theme.Colors.Gems, "Gems")
	local rebirths = pill(3, "🔁", Theme.Colors.Rebirth, nil)

	-- Luck: level from clovers, total luck multiplier and progress to the next level.
	local luckButton = Util.button({
		LayoutOrder = 4,
		Color = Theme.Colors.Panel,
		CornerRadius = 22,
		Size = UDim2.fromOffset(240, 50),
		Parent = panel,
	}, function()
		Windows.open("Stats")
	end)
	Util.label({
		Size = UDim2.fromOffset(34, 30),
		Position = UDim2.fromOffset(2, 2),
		Text = "🍀",
		Parent = luckButton,
	})
	local luckText = Util.label({
		Size = UDim2.new(1, -44, 0, 26),
		Position = UDim2.fromOffset(40, 2),
		Text = "",
		TextColor3 = Theme.Colors.Luck,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = luckButton,
	})
	local _, setLuckBar = Util.bar({
		Size = UDim2.new(1, -12, 0, 10),
		Position = UDim2.fromOffset(6, 32),
		Color = Theme.Colors.Luck,
		CornerRadius = 5,
		Parent = luckButton,
	})
	State.watch({ "LuckXP", "Upgrades", "Boosts", "Session.Passes" }, function()
		local xp = State.Data.LuckXP or 0
		local level = Formula.luckLevel(xp)
		local current = Formula.luckXPForLevel(level)
		local nextXP = Formula.luckXPForLevel(level + 1)
		luckText.Text = "Luck Lv " .. level .. "  ·  " .. Format.multiplier(Formula.luck(State.Data, State.Session))
		setLuckBar((xp - current) / math.max(nextXP - current, 1))
	end)

	State.watch({ "Coins", "Gems", "Rebirths" }, function()
		local data = State.Data
		coins.Text = Format.number(data.Coins)
		gems.Text = Format.number(data.Gems)
		rebirths.Text =
			string.format("%d  (%s)", data.Rebirths, Format.multiplier(Formula.rebirthMultiplier(data.Rebirths)))
	end)
end

local function buildMenu(screen: ScreenGui)
	local menu = Util.new("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 80),
		Size = UDim2.fromOffset(230, 310),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		Util.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(70, 70),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	Util.autoScale(menu)

	for order, item in MENU do
		local button = Util.button({
			Name = item.Window,
			LayoutOrder = order,
			Color = item.Color,
			CornerRadius = 16,
			Parent = menu,
		}, function()
			Windows.toggle(item.Window)
		end)
		Util.label({ Size = UDim2.fromScale(1, 0.62), Text = item.Icon, Parent = button })
		Util.label({
			Size = UDim2.fromScale(1, 0.3),
			Position = UDim2.fromScale(0, 0.66),
			Text = item.Window,
			Parent = button,
		})
		local badge = Util.new("Frame", {
			Name = "Badge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = Theme.Colors.Red,
			Visible = false,
			ZIndex = 3,
			Parent = button,
		}, { Util.corner(12), Util.stroke(nil, 2) })
		Util.label({ Size = UDim2.fromScale(1, 1), Text = "!", ZIndex = 4, Parent = badge })
		badges[item.Window] = badge
	end
end

local function currentGoal(): (string, number, number)
	local data = State.Data
	if data.Stats.EggsHatched == 0 then
		local egg = Eggs.List[1]
		return "Hatch your first pet at the " .. egg.Name .. "!", data.Coins, egg.Price
	end
	local nextZone = Zones.List[data.HighestZone + 1]
	if nextZone then
		return "Unlock " .. nextZone.Icon .. " " .. nextZone.Name, data.Coins, nextZone.UnlockCost
	end
	return "Rebirth for a permanent coin boost!", data.Coins, Formula.rebirthCost(data.Rebirths)
end

local function buildGoal(screen: ScreenGui)
	local frame = Util.new("Frame", {
		Name = "Goal",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(400, 66),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = screen,
	}, { Util.corner(16), Util.stroke(nil, 3) })
	Util.autoScale(frame)
	local title =
		Util.label({ Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 5), Text = "", Parent = frame })
	local _, setBar = Util.bar({ Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 35), Parent = frame })

	local chips = Util.new("Frame", {
		Name = "Boosts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 82),
		Size = UDim2.fromOffset(600, 34),
		BackgroundTransparency = 1,
		Parent = screen,
	}, { Util.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center) })
	Util.autoScale(chips)
	local function chip(order: number, color: Color3): TextLabel
		local label = Util.label({
			LayoutOrder = order,
			Size = UDim2.fromOffset(150, 32),
			BackgroundTransparency = 0,
			BackgroundColor3 = color,
			Text = "",
			Visible = false,
			Parent = chips,
		})
		Util.corner(16).Parent = label
		Util.new("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			Parent = label,
		})
		return label
	end
	local coinBoost = chip(1, Theme.Colors.Orange)
	local luckBoost = chip(2, Theme.Colors.Green)
	local friends = chip(3, Theme.Colors.Blue)

	State.watch({ "Coins", "Stats", "HighestZone", "Rebirths" }, function()
		local text, current, target = currentGoal()
		local ready = current >= target
		title.Text = (if ready then "✅ " else "🎯 ") .. text
		title.TextColor3 = if ready then Theme.Colors.Green else Theme.Colors.Text
		setBar(current / target, Format.number(current) .. " / " .. Format.number(target))
	end)
	State.watch({ "Boosts", "Session.FriendBonus" }, function()
		local boosts = State.Data.Boosts
		coinBoost.Visible = boosts.Coins > 0
		coinBoost.Text = "⚡ 2x Coins " .. Format.time(boosts.Coins)
		luckBoost.Visible = boosts.Luck > 0
		luckBoost.Text = "🍀 2x Luck " .. Format.time(boosts.Luck)
		local bonus = State.Session.FriendBonus or 0
		friends.Visible = bonus > 0
		friends.Text = "👋 Friends +" .. math.floor(bonus * 100 + 0.5) .. "%"
	end)
end

local function buildTap(screen: ScreenGui)
	local holder = Util.new("Frame", {
		Name = "TapArea",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(160, 190),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	Util.autoScale(holder)

	Hud.TapArea = holder

	tapValueLabel = Util.label({
		Size = UDim2.fromOffset(240, 30),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Text = "",
		TextColor3 = Theme.Colors.Coins,
		Parent = holder,
	})

	tapButton = Util.button({
		Name = "Tap",
		Color = Theme.Colors.Coins,
		CornerRadius = 80,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(150, 150),
		Parent = holder,
	}, function()
		if onTap then
			onTap()
		end
	end)
	Util.gradient(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 150, 30)).Parent = tapButton
	Util.label({
		Size = UDim2.fromScale(0.8, 0.4),
		Position = UDim2.fromScale(0.1, 0.2),
		Text = "TAP!",
		Parent = tapButton,
	})
	Util.label({
		Size = UDim2.fromScale(0.6, 0.2),
		Position = UDim2.fromScale(0.2, 0.62),
		Text = "🪙",
		Parent = tapButton,
	})

	State.watch({
		"Upgrades",
		"Pets",
		"Rebirths",
		"HighestZone",
		"Boosts",
		"Session.Passes",
		"Session.FriendBonus",
		"Session.Premium",
	}, function()
		tapValueLabel.Text = "+" .. Format.number(Formula.tapValue(State.Data, State.Session)) .. " per tap"
	end)

	local auto = Util.button({
		Name = "AutoTap",
		Color = Theme.Colors.Gray,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(1, 12, 1, -20),
		Size = UDim2.fromOffset(140, 48),
		Parent = holder,
	}, function()
		if State.Session.Passes.AutoTap then
			Actions("SetAutoTap", not State.Session.AutoTap)
		else
			Actions("BuyPass", "AutoTap")
		end
	end)
	State.watch({ "Session.Passes", "Session.AutoTap" }, function()
		local owned = State.Session.Passes.AutoTap
		if not owned then
			auto.Text = "🤖 Auto 🔒"
			auto.BackgroundColor3 = Theme.Colors.Gray
		elseif State.Session.AutoTap then
			auto.Text = "🤖 Auto: ON"
			auto.BackgroundColor3 = Theme.Colors.Green
		else
			auto.Text = "🤖 Auto: OFF"
			auto.BackgroundColor3 = Theme.Colors.Red
		end
	end)
end

local function giftStatus(): (boolean, number)
	local session = State.Session
	local elapsed = workspace:GetServerTimeNow() - session.JoinedAt
	local nextIn = math.huge
	for index, gift in Config.Gifts do
		if not session.GiftsClaimed[index] then
			local remaining = gift.Minutes * 60 - elapsed
			if remaining <= 0 then
				return true, 0
			end
			nextIn = math.min(nextIn, remaining)
		end
	end
	return false, nextIn
end

local function buildRightColumn(screen: ScreenGui, openShop: (string) -> ())
	local column = Util.new("Frame", {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(180, 150),
		BackgroundTransparency = 1,
		Parent = screen,
	}, { Util.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Right) })
	Util.autoScale(column)

	local gifts = Util.button(
		{ LayoutOrder = 1, Color = Theme.Colors.Gold, Size = UDim2.fromOffset(180, 64), Parent = column },
		function()
			Windows.open("Gifts")
		end
	)
	local starter = Util.button(
		{ LayoutOrder = 2, Color = Theme.Colors.Rebirth, Size = UDim2.fromOffset(180, 64), Parent = column },
		function()
			openShop("Featured")
		end
	)
	Util.gradient(Color3.fromRGB(255, 180, 90), Color3.fromRGB(255, 80, 170)).Parent = starter
	local pack = Products.ProductByKey.StarterPack
	starter.Text = "🎁 Starter Pack\nR$ " .. pack.Price
	State.watch({ "OneTime" }, function()
		starter.Visible = not State.Data.OneTime.StarterPack
	end)

	task.spawn(function()
		while gifts.Parent do
			local ready, nextIn = giftStatus()
			gifts.Text = if ready then "🎁 Free Gift!\nREADY!" else "🎁 Free Gift\nin " .. Format.time(nextIn)
			local press = gifts:FindFirstChild("Press") :: UIScale
			if ready then
				Util.tween(press, 0.5, { Scale = 1.08 }, Enum.EasingStyle.Sine)
				task.wait(0.5)
				Util.tween(press, 0.5, { Scale = 1 }, Enum.EasingStyle.Sine)
				task.wait(0.5)
			else
				task.wait(1)
			end
		end
	end)
end

local function refreshBadges()
	local data, session = State.Data, State.Session
	local dailyReady = Formula.dailyStatus(data.Daily, workspace:GetServerTimeNow())
	badges.Daily.Visible = dailyReady
	badges.Gifts.Visible = (giftStatus())
	local questReady = false
	for _, quest in data.Quests do
		if Quests.progress(data, quest) >= quest.Goal then
			questReady = true
		end
	end
	badges.Quests.Visible = questReady
	badges.Rebirth.Visible = data.Coins >= Formula.rebirthCost(data.Rebirths)
	local hasFreeSlot = false
	local equipped = 0
	for _, pet in data.Pets do
		if pet.Equipped then
			equipped += 1
		end
	end
	local count = Formula.petCount(data)
	hasFreeSlot = equipped < Formula.equipSlots(data, session) and equipped < count
	badges.Pets.Visible = hasFreeSlot or count >= Config.Pets.Storage * 0.9
end

-- Floating "+123" above the TAP button.
function Hud.popTap(amount: number, faint: boolean?)
	local label = Util.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, math.random(-70, 70), 0, math.random(-10, 20)),
		Size = UDim2.fromOffset(160, if faint then 26 else 34),
		Text = "+" .. Format.number(amount),
		TextColor3 = Theme.Colors.Coins,
		TextTransparency = if faint then 0.35 else 0,
		ZIndex = 4,
		Parent = tapButton,
	})
	Util.tween(label, 0.7, { Position = label.Position - UDim2.fromOffset(0, 90), TextTransparency = 1 })
	task.delay(0.7, function()
		label:Destroy()
	end)
	local press = tapButton:FindFirstChild("Press") :: UIScale
	if not faint then
		press.Scale = 0.9
		Util.tween(press, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

function Hud.build(screen: ScreenGui, tapHandler: () -> (), openShop: (string) -> ())
	onTap = tapHandler
	buildCurrencies(screen, openShop)
	buildMenu(screen)
	buildGoal(screen)
	buildTap(screen)
	buildRightColumn(screen, openShop)

	State.watch(
		{ "Coins", "Stats", "Quests", "Daily", "Pets", "Rebirths", "Session.GiftsClaimed", "Session.JoinedAt" },
		refreshBadges
	)
	task.spawn(function()
		while true do
			task.wait(1)
			refreshBadges()
		end
	end)

	-- Cosmetic numbers while the Auto Tapper runs on the server.
	task.spawn(function()
		while true do
			task.wait(1 / Config.Tap.AutoPerSecond)
			if State.Session.AutoTap and State.Session.Passes.AutoTap then
				Hud.popTap(Formula.tapValue(State.Data, State.Session), true)
			end
		end
	end)
end

return Hud
