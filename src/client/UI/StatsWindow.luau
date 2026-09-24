--[[
	Stats: where your luck and coins come from, and lifetime totals.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Formula = require(Shared.Formula)
local Zones = require(Shared.Zones)

local PetModels = require(script.Parent.Parent.PetModels)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Windows = require(script.Parent.Windows)

local StatsWindow = {}

local NAME = "Stats"

local function percent(value: number): string
	return "+" .. Format.number(math.floor(value * 1000 + 0.5) / 10) .. "%"
end

function StatsWindow.build()
	local body = Windows.create(NAME, "📊 Stats", Theme.Colors.Luck, Vector2.new(600, 490))
	local list = Util.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	}, { Util.list(Enum.FillDirection.Vertical, 6) })

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local function header(text: string, color: Color3)
		Util.label({
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -12, 0, 32),
			Text = text,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = list,
		})
	end

	local function row(name: string, highlight: boolean?): TextLabel
		local frame = Util.new("Frame", {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -12, 0, 30),
			BackgroundColor3 = if highlight then Theme.Colors.PanelLight else Theme.Colors.Panel,
			Parent = list,
		}, { Util.corner(10) })
		Util.label({
			Size = UDim2.new(0.62, -12, 1, -8),
			Position = UDim2.fromOffset(12, 4),
			Text = name,
			TextColor3 = if highlight then Theme.Colors.Text else Theme.Colors.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		return Util.label({
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.new(0.38, -12, 1, -8),
			Position = UDim2.new(1, -12, 0, 4),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = frame,
		})
	end

	-- Luck
	header("🍀 Luck", Theme.Colors.Luck)
	local luckLevel = Util.label({
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, -12, 0, 30),
		Text = "",
		Parent = list,
	})
	local barHolder = Util.new("Frame", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, -12, 0, 28),
		BackgroundTransparency = 1,
		Parent = list,
	})
	local _, setLuckBar = Util.bar({ Size = UDim2.fromScale(1, 1), Color = Theme.Colors.Luck, Parent = barHolder })
	local fromLevel = row("Luck Level (+" .. math.floor(Config.Luck.PerLevel * 100 + 0.5) .. "% each)")
	local fromUpgrade = row("Egg Luck upgrade")
	local fromPass = row("Lucky Eggs pass")
	local fromBoost = row("2x Luck boost")
	local totalLuck = row("Total luck", true)
	local cloverValues = {}
	for _, zone in Zones.List do
		table.insert(cloverValues, zone.Icon .. " " .. zone.CloverValue)
	end
	Util.label({
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, -12, 0, 58),
		Text = "Pick up 🍀 clovers on the ground to level up your luck. Better areas give more Luck XP per clover ("
			.. table.concat(cloverValues, ", ")
			.. "). Luck raises the chance of Rare and better pets.",
		TextColor3 = Theme.Colors.SubText,
		TextWrapped = true,
		Parent = list,
	})

	-- Coins
	header("🪙 Coins per tap", Theme.Colors.Coins)
	local basePower = row("Tap Power")
	local petMultiplier = row("Equipped pets")
	local rebirthMultiplier = row("Rebirths")
	local zoneMultiplier = row("Best area")
	local masteryMultiplier = row("Coin Mastery")
	local passMultiplier = row("Passes & Premium")
	local friendMultiplier = row("Friends in server")
	local coinBoost = row("2x Coins boost")
	local perTap = row("Coins per tap", true)

	-- Lifetime
	header("📈 Lifetime", Theme.Colors.Blue)
	local taps = row("Taps")
	local coinsEarned = row("Coins earned")
	local eggs = row("Eggs hatched")
	local clovers = row("Clovers picked up")
	local luckXP = row("Luck XP")
	local discovered = row("Pets discovered")
	local rebirths = row("Rebirths")
	local quests = row("Quests completed")
	local timePlayed = row("Time played")

	local indexTotal = #PetModels.indexOrder()

	local function refresh()
		local data, session = State.Data, State.Session
		local luck = Formula.luckBreakdown(data, session)
		local xp = data.LuckXP or 0
		local current = Formula.luckXPForLevel(luck.Level)
		local nextXP = Formula.luckXPForLevel(luck.Level + 1)
		if luck.Level >= Config.Luck.MaxLevel then
			luckLevel.Text = "Luck Level " .. luck.Level .. " (MAX)"
			setLuckBar(1, Format.number(xp) .. " Luck XP")
		else
			luckLevel.Text = "Luck Level " .. luck.Level
			setLuckBar(
				(xp - current) / math.max(nextXP - current, 1),
				Format.number(xp - current)
					.. " / "
					.. Format.number(nextXP - current)
					.. " XP to Lv "
					.. luck.Level + 1
			)
		end
		fromLevel.Text = percent(luck.FromLevel)
		fromUpgrade.Text = percent(luck.FromUpgrade)
		fromPass.Text = if session.Passes.Lucky then percent(luck.FromPass) else "not owned"
		fromBoost.Text = if luck.BoostMultiplier > 1
			then "x" .. luck.BoostMultiplier .. " (" .. Format.time(data.Boosts.Luck) .. ")"
			else "inactive"
		totalLuck.Text = Format.multiplier(luck.Total)
		totalLuck.TextColor3 = Theme.Colors.Luck

		basePower.Text = Format.number(Formula.tapPower(Formula.level(data, "TapPower")))
		petMultiplier.Text = Format.multiplier(1 + Formula.petBonus(data))
		rebirthMultiplier.Text = Format.multiplier(Formula.rebirthMultiplier(data.Rebirths))
		zoneMultiplier.Text = Format.multiplier(Formula.zoneMultiplier(data))
		masteryMultiplier.Text = Format.multiplier(Formula.masteryMultiplier(Formula.level(data, "CoinMastery")))
		passMultiplier.Text = Format.multiplier(Formula.passMultiplier(session))
		friendMultiplier.Text = Format.multiplier(1 + (session.FriendBonus or 0))
		coinBoost.Text = if (data.Boosts.Coins or 0) > 0
			then "x" .. Config.Bonuses.CoinBoostMultiplier .. " (" .. Format.time(data.Boosts.Coins) .. ")"
			else "inactive"
		perTap.Text = "🪙 " .. Format.number(Formula.tapValue(data, session))
		perTap.TextColor3 = Theme.Colors.Coins

		local stats = data.Stats
		taps.Text = Format.commas(stats.Taps)
		coinsEarned.Text = Format.number(stats.CoinsEarned)
		eggs.Text = Format.commas(stats.EggsHatched)
		clovers.Text = Format.commas(stats.OrbsCollected)
		luckXP.Text = Format.commas(xp)
		local found = 0
		for _ in data.Index do
			found += 1
		end
		discovered.Text = found .. " / " .. indexTotal
		rebirths.Text = Format.commas(data.Rebirths)
		quests.Text = Format.commas(data.QuestsCompleted)
		timePlayed.Text = Format.time(stats.TimePlayed)
	end

	State.watch(nil, function()
		if Windows.isOpen(NAME) then
			refresh()
		end
	end)
	Windows.onOpen(NAME, refresh)
end

return StatsWindow
