--[[
	Always-on screen elements, grouped so each side of the screen has one job:

	- Top left: your currencies and luck, then the four core actions (Pets, Upgrades, Rebirth,
	  Shop). Kept high so it stays clear of the phone thumbstick.
	- Right: rewards to collect (Quests, Daily, Gifts, Offline) with alert badges, the starter
	  pack offer, and small utility buttons (Stats, Codes, Settings, Admin).
	- Top centre: the next goal and any active boosts.
	- Bottom centre: the TAP button, with Auto Tap and Auto Hatch beside it.
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

type Item = { Window: string, Icon: string, Label: string?, Color: Color3 }

-- Width of the left and right rails; each holds a 2×2 grid of tiles.
local RAIL_WIDTH = 180
local TILE = (RAIL_WIDTH - Theme.Gap) / 2
local UTILITY = 36

local CORE: { Item } = {
	{ Window = "Pets", Icon = "🐾", Color = Theme.Colors.Orange },
	{ Window = "Upgrades", Icon = "⬆️", Color = Theme.Colors.Blue },
	{ Window = "Rebirth", Icon = "🔁", Color = Theme.Colors.Rebirth },
	{ Window = "Shop", Icon = "🛒", Color = Theme.Colors.Green },
}

local REWARDS: { Item } = {
	{ Window = "Quests", Icon = "📜", Color = Theme.Colors.Purple },
	{ Window = "Daily", Icon = "📅", Color = Theme.Colors.Red },
	{ Window = "Gifts", Icon = "🎁", Color = Theme.Colors.Gold },
	{ Window = "Offline", Icon = "💤", Label = "Away", Color = Theme.Colors.Blue },
}

local TOOLS: { Item } = {
	{ Window = "Stats", Icon = "📊", Color = Theme.Colors.PanelLight },
	{ Window = "Codes", Icon = "🎫", Color = Theme.Colors.PanelLight },
	{ Window = "Settings", Icon = "⚙️", Color = Theme.Colors.PanelLight },
}

local tapButton: TextButton
local badges: { [string]: Frame } = {}
local captions: { [string]: TextLabel } = {}
local tiles: { [string]: TextButton } = {}
local onTap: (() -> ())? = nil

-- A square menu button: big icon, caption underneath and an alert badge in the corner.
local function tile(parent: Instance, order: number, item: Item): TextButton
	local button = Util.button({
		Name = item.Window,
		LayoutOrder = order,
		Color = item.Color,
		Parent = parent,
	}, function()
		Windows.toggle(item.Window)
	end)
	Util.label({
		Size = UDim2.fromScale(1, 0.56),
		Position = UDim2.fromScale(0, 0.04),
		Text = item.Icon,
		Parent = button,
	})
	captions[item.Window] = Util.label({
		Size = UDim2.fromScale(1, 0.28),
		Position = UDim2.fromScale(0, 0.64),
		Text = item.Label or item.Window,
		Parent = button,
	})
	local badge = Util.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Theme.Colors.Red,
		Visible = false,
		ZIndex = 3,
		Parent = button,
	}, { Util.corner(12), Util.stroke(Theme.Colors.Text, 2) })
	Util.label({ Size = UDim2.fromScale(1, 1), Text = "!", ZIndex = 4, Parent = badge })
	badges[item.Window] = badge
	tiles[item.Window] = button
	return button
end

local function grid(parent: Instance, order: number, items: { Item })
	local frame = Util.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(RAIL_WIDTH, TILE * 2 + Theme.Gap),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Util.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(TILE, TILE),
			CellPadding = UDim2.fromOffset(Theme.Gap, Theme.Gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, item in items do
		tile(frame, index, item)
	end
end

-- Left rail -----------------------------------------------------------------------------------

local function buildCurrencies(parent: Instance, openShop: (string) -> ())
	local card = Util.panel({
		LayoutOrder = 1,
		Size = UDim2.fromOffset(RAIL_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = parent,
	}, { Util.padding(Theme.Gap), Util.list(Enum.FillDirection.Vertical, 6) })

	local function row(order: number, icon: string, color: Color3, shopTab: string): TextLabel
		local frame = Util.new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
			Parent = card,
		})
		Util.label({ Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(0, 2), Text = icon, Parent = frame })
		local amount = Util.label({
			Size = UDim2.new(1, -72, 0, 26),
			Position = UDim2.fromOffset(34, 3),
			Text = "0",
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		Util.button({
			Text = "+",
			Color = Theme.Colors.Green,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(30, 28),
			CornerRadius = 10,
			Parent = frame,
		}, function()
			openShop(shopTab)
		end)
		return amount
	end

	local coins = row(1, "🪙", Theme.Colors.Coins, "Coins")
	local gems = row(2, "💎", Theme.Colors.Gems, "Gems")

	-- Luck: level from clovers, total luck multiplier and progress to the next level.
	local luck = Util.new("TextButton", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundTransparency = 1,
		Text = "",
		Parent = card,
	})
	luck.Activated:Connect(function()
		Windows.open("Stats")
	end)
	Util.label({ Size = UDim2.fromOffset(28, 26), Position = UDim2.fromOffset(0, 0), Text = "🍀", Parent = luck })
	local luckText = Util.label({
		Size = UDim2.new(1, -34, 0, 24),
		Position = UDim2.fromOffset(34, 1),
		Text = "",
		TextColor3 = Theme.Colors.Luck,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = luck,
	})
	local _, setLuckBar = Util.bar({
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.fromOffset(0, 30),
		Color = Theme.Colors.Luck,
		CornerRadius = 5,
		Parent = luck,
	})

	State.watch({ "LuckXP", "Upgrades", "Boosts", "Session.Passes" }, function()
		local xp = State.Data.LuckXP or 0
		local level = Formula.luckLevel(xp)
		local current = Formula.luckXPForLevel(level)
		local nextXP = Formula.luckXPForLevel(level + 1)
		luckText.Text = "Lv " .. level .. "  ·  " .. Format.multiplier(Formula.luck(State.Data, State.Session))
		setLuckBar((xp - current) / math.max(nextXP - current, 1))
	end)
	State.watch({ "Coins", "Gems" }, function()
		coins.Text = Format.number(State.Data.Coins)
		gems.Text = Format.number(State.Data.Gems)
	end)
end

local function buildLeftRail(screen: ScreenGui, openShop: (string) -> ())
	local rail = Util.new("Frame", {
		Name = "LeftRail",
		Position = UDim2.fromOffset(Theme.Margin, Theme.Margin),
		Size = UDim2.fromOffset(RAIL_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = screen,
	}, { Util.list(Enum.FillDirection.Vertical, 10) })
	Util.autoScale(rail)
	buildCurrencies(rail, openShop)
	grid(rail, 2, CORE)
end

-- Right rail ----------------------------------------------------------------------------------

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

local function buildRightRail(screen: ScreenGui, openShop: (string) -> ())
	local rail = Util.new("Frame", {
		Name = "RightRail",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -Theme.Margin, 0.42, 0),
		Size = UDim2.fromOffset(RAIL_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = screen,
	}, { Util.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Right) })
	Util.autoScale(rail)

	grid(rail, 1, REWARDS)

	local pack = Products.ProductByKey.StarterPack
	local starter = Util.button({
		LayoutOrder = 2,
		Text = "🎁 Starter Pack  ·  R$ " .. pack.Price,
		Color = Theme.Colors.Rebirth,
		Size = UDim2.fromOffset(RAIL_WIDTH, 44),
		Parent = rail,
	}, function()
		openShop("Featured")
	end)
	Util.sheen(starter, Color3.fromRGB(255, 190, 110), Color3.fromRGB(255, 90, 175))
	State.watch({ "OneTime" }, function()
		starter.Visible = not State.Data.OneTime.StarterPack
	end)

	local tools = Util.new("Frame", {
		LayoutOrder = 3,
		Size = UDim2.fromOffset(RAIL_WIDTH, UTILITY),
		BackgroundTransparency = 1,
		Parent = rail,
	}, { Util.list(Enum.FillDirection.Horizontal, Theme.Gap, Enum.HorizontalAlignment.Right) })
	for order, item in TOOLS do
		local button = Util.button({
			Name = item.Window,
			LayoutOrder = order,
			Text = item.Icon,
			Color = item.Color,
			Size = UDim2.fromOffset(UTILITY, UTILITY),
			CornerRadius = 10,
			Parent = tools,
		}, function()
			Windows.toggle(item.Window)
		end)
		tiles[item.Window] = button
	end
	-- Only admins (Studio, the place owner, Config.Admins) see this; the server checks too.
	local admin = Util.button({
		Name = "Admin",
		LayoutOrder = 0,
		Text = "🛠",
		Color = Theme.Colors.Red,
		Size = UDim2.fromOffset(UTILITY, UTILITY),
		CornerRadius = 10,
		Visible = false,
		Parent = tools,
	}, function()
		Windows.toggle("Admin")
	end)
	State.watch({ "Session.IsAdmin" }, function()
		admin.Visible = State.Session.IsAdmin == true
	end)

	-- The Gifts tile shows the countdown to the next gift and bounces when one is ready.
	local gifts = tiles.Gifts
	local giftCaption = captions.Gifts
	task.spawn(function()
		while gifts.Parent do
			local ready, nextIn = giftStatus()
			giftCaption.Text = if ready then "Ready!" elseif nextIn == math.huge then "Gifts" else Format.time(nextIn)
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

-- Top centre: goal and boosts -----------------------------------------------------------------

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
	local top = Util.new("Frame", {
		Name = "Goal",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Theme.Margin),
		Size = UDim2.fromOffset(360, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = screen,
	}, { Util.list(Enum.FillDirection.Vertical, Theme.Gap, Enum.HorizontalAlignment.Center) })
	Util.autoScale(top)

	local card = Util.panel({
		LayoutOrder = 1,
		Size = UDim2.fromOffset(360, 58),
		Parent = top,
	})
	local title = Util.label({
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.fromOffset(10, 6),
		Text = "",
		Parent = card,
	})
	local _, setBar = Util.bar({ Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 33), Parent = card })

	local chips = Util.new("Frame", {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(480, 30),
		BackgroundTransparency = 1,
		Parent = top,
	}, { Util.list(Enum.FillDirection.Horizontal, Theme.Gap, Enum.HorizontalAlignment.Center) })
	local function chip(order: number, color: Color3): TextLabel
		local label = Util.label({
			LayoutOrder = order,
			Size = UDim2.fromOffset(150, 28),
			BackgroundTransparency = 0,
			BackgroundColor3 = color,
			Text = "",
			Visible = false,
			Parent = chips,
		})
		Util.corner(14).Parent = label
		Util.padding(5).Parent = label
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

-- Bottom centre: TAP ------------------------------------------------------------------------------

local function buildTap(screen: ScreenGui)
	local holder = Util.new("Frame", {
		Name = "TapArea",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -Theme.Margin),
		Size = UDim2.fromOffset(150, 176),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	Util.autoScale(holder)
	Hud.TapArea = holder

	local tapValue = Util.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(240, 26),
		Text = "",
		TextColor3 = Theme.Colors.Coins,
		Parent = holder,
	})

	tapButton = Util.button({
		Name = "Tap",
		Color = Theme.Colors.Coins,
		CornerRadius = 70,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(140, 140),
		Parent = holder,
	}, function()
		if onTap then
			onTap()
		end
	end)
	Util.sheen(tapButton, Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 150, 30))
	Util.label({
		Size = UDim2.fromScale(0.76, 0.36),
		Position = UDim2.fromScale(0.12, 0.2),
		Text = "TAP!",
		Parent = tapButton,
	})
	Util.label({
		Size = UDim2.fromScale(0.5, 0.2),
		Position = UDim2.fromScale(0.25, 0.6),
		Text = "🪙",
		Parent = tapButton,
	})

	State.watch({
		"Upgrades",
		"Pets",
		"Index",
		"Rebirths",
		"HighestZone",
		"Boosts",
		"Session.Passes",
		"Session.FriendBonus",
		"Session.Premium",
	}, function()
		tapValue.Text = "+" .. Format.number(Formula.tapValue(State.Data, State.Session)) .. " per tap"
	end)

	local auto = Util.button({
		Name = "AutoTap",
		Color = Theme.Colors.Gray,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(1, 12, 1, -20),
		Size = UDim2.fromOffset(140, 44),
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
			auto.BackgroundColor3 = Theme.Colors.Gray
		end
	end)
end

-- Badges ---------------------------------------------------------------------------------------

local function refreshBadges()
	local data, session = State.Data, State.Session
	badges.Daily.Visible = (Formula.dailyStatus(data.Daily, workspace:GetServerTimeNow()))
	badges.Gifts.Visible = (giftStatus())
	local questReady = false
	for _, quest in data.Quests do
		if Quests.progress(data, quest) >= quest.Goal then
			questReady = true
		end
	end
	for _, quest in (data.Weekly and data.Weekly.Quests or {}) do
		if not quest.Claimed and Quests.progress(data, quest) >= quest.Goal then
			questReady = true
		end
	end
	badges.Quests.Visible = questReady
	badges.Rebirth.Visible = data.Coins >= Formula.rebirthCost(data.Rebirths)
	badges.Offline.Visible = data.Offline ~= nil and data.Offline.Coins > 0
	local equipped = 0
	for _, pet in data.Pets do
		if pet.Equipped then
			equipped += 1
		end
	end
	local count = Formula.petCount(data)
	local hasFreeSlot = equipped < Formula.equipSlots(data, session) and equipped < count
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
	buildLeftRail(screen, openShop)
	buildRightRail(screen, openShop)
	buildGoal(screen)
	buildTap(screen)

	State.watch({
		"Coins",
		"Stats",
		"Quests",
		"Weekly",
		"Daily",
		"Pets",
		"Rebirths",
		"Offline",
		"Session.GiftsClaimed",
		"Session.JoinedAt",
	}, refreshBadges)
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
