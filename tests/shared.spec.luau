-- Appended to the bundle built by tests/run.py; `shared(name)` returns a shared module.

local Config = shared("Config")
local Eggs = shared("Eggs")
local Format = shared("Format")
local Formula = shared("Formula")
local Pets = shared("Pets")
local Products = shared("Products")
local Quests = shared("Quests")
local Rewards = shared("Rewards")
local Upgrades = shared("Upgrades")
local Zones = shared("Zones")

local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. "\n      " .. tostring(err))
	end
end

local function eq(actual, expected, label: string?)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", label or "value", tostring(expected), tostring(actual)), 2)
	end
end

local function near(actual: number, expected: number, tolerance: number, label: string?)
	if math.abs(actual - expected) > tolerance then
		error(string.format("%s: expected %s ± %s, got %s", label or "value", expected, tolerance, actual), 2)
	end
end

local function freshData()
	return {
		Coins = 0,
		Gems = 0,
		Rebirths = 0,
		HighestZone = 1,
		Upgrades = {},
		Pets = {},
		Index = {},
		Boosts = { Coins = 0, Luck = 0 },
		Daily = { Last = 0, Streak = 0 },
		Quests = {},
		QuestsCompleted = 0,
		Stats = { Taps = 0, CoinsEarned = 0, EggsHatched = 0, OrbsCollected = 0 },
	}
end

local function freshSession()
	return { Passes = {}, Premium = false, FriendBonus = 0 }
end

-- Catalog consistency ------------------------------------------------------------------------

test("every egg pet exists and has a known rarity", function()
	for _, egg in Eggs.List do
		for _, entry in egg.Pets do
			local pet = Pets[entry.Id]
			assert(pet, egg.Id .. " references missing pet " .. entry.Id)
			assert(Config.Rarities[pet.Rarity], entry.Id .. " has unknown rarity " .. pet.Rarity)
			assert(entry.Weight > 0, entry.Id .. " has no weight")
		end
	end
end)

test("every non-exclusive pet can be hatched", function()
	local hatchable = {}
	for _, egg in Eggs.List do
		for _, entry in egg.Pets do
			hatchable[entry.Id] = true
		end
	end
	for petId, pet in Pets do
		assert(pet.Exclusive or hatchable[petId], petId .. " is in no egg and not marked Exclusive")
	end
end)

test("pet features are ones the model builder knows", function()
	local known = {
		DogEars = true,
		CatEars = true,
		BunnyEars = true,
		BearEars = true,
		Wings = true,
		Antenna = true,
		Horns = true,
		Horn = true,
		Halo = true,
		Beak = true,
		Crown = true,
		Tentacles = true,
	}
	for petId, pet in Pets do
		for _, feature in pet.Features do
			assert(known[feature], petId .. " uses unknown feature " .. feature)
		end
	end
end)

test("areas and eggs get steadily pricier", function()
	for index = 2, #Zones.List do
		assert(Zones.List[index].UnlockCost > Zones.List[index - 1].UnlockCost, "zone " .. index .. " cost")
		assert(Zones.List[index].TapMultiplier > Zones.List[index - 1].TapMultiplier, "zone " .. index .. " multiplier")
	end
	for index, egg in Eggs.List do
		eq(egg.Zone, index, egg.Id .. " zone")
		if index > 1 then
			assert(egg.Price > Eggs.List[index - 1].Price, egg.Id .. " price")
		end
	end
end)

test("shop items are unique and reward real things", function()
	local keys = {}
	for _, pass in Products.GamePasses do
		assert(not keys[pass.Key], "duplicate key " .. pass.Key)
		keys[pass.Key] = true
		assert(pass.Price > 0, pass.Key .. " price")
	end
	for _, product in Products.DevProducts do
		assert(not keys[product.Key], "duplicate key " .. product.Key)
		keys[product.Key] = true
		assert(product.Price > 0, product.Key .. " price")
		assert(table.find(Products.Categories, product.Category), product.Key .. " category")
		assert(next(product.Reward) ~= nil, product.Key .. " grants nothing")
		if product.Reward.Pet then
			assert(Pets[product.Reward.Pet], product.Key .. " grants a missing pet")
		end
		assert(Rewards.describe(product.Reward, freshData(), freshSession()) ~= "", product.Key .. " description")
	end
end)

test("bigger packs are better value", function()
	local function perRobux(key: string, field: string): number
		local product = Products.ProductByKey[key]
		return (product.Reward :: any)[field] / product.Price
	end
	assert(perRobux("CoinsMedium", "CoinSeconds") > perRobux("CoinsSmall", "CoinSeconds"), "coins medium")
	assert(perRobux("CoinsLarge", "CoinSeconds") > perRobux("CoinsMedium", "CoinSeconds"), "coins large")
	assert(perRobux("GemsMedium", "Gems") > perRobux("GemsSmall", "Gems"), "gems medium")
	assert(perRobux("GemsLarge", "Gems") > perRobux("GemsMedium", "Gems"), "gems large")
end)

test("reward tables only use known fields", function()
	local allowed = { Gems = true, CoinSeconds = true, CoinBoostMinutes = true, LuckBoostMinutes = true }
	local function check(reward, label)
		for key in reward do
			assert(allowed[key], label .. " uses unknown field " .. key)
		end
	end
	for day, reward in Config.Daily.Rewards do
		check(reward, "daily " .. day)
	end
	for index, gift in Config.Gifts do
		check(gift.Reward, "gift " .. index)
	end
	for code, reward in Config.Codes do
		eq(code, string.upper(code), "codes are stored upper-case")
		check(reward, "code " .. code)
	end
end)

test("auto-delete can never remove Legendary or rarer pets", function()
	for _, rarity in Config.Pets.AutoDeletable do
		local info = Config.Rarities[rarity]
		assert(info, "unknown rarity " .. rarity)
		assert(not info.Announce, rarity .. " is too rare to auto-delete")
	end
end)

test("each pet tier is stronger than the one below and worth crafting", function()
	eq(Config.Tiers[1].Multiplier, 1, "Normal tier")
	for index = 2, #Config.Tiers do
		local tier, below = Config.Tiers[index], Config.Tiers[index - 1]
		assert(tier.Multiplier > below.Multiplier, tier.Name .. " must beat " .. below.Name)
		assert(tier.Color and tier.Accent, tier.Name .. " needs colours for repainting")
		-- Crafting trades CraftCopies pets for one: it should always free up slots for a stronger pet.
		assert(tier.Multiplier > below.Multiplier * 2, tier.Name .. " is too weak to be worth crafting")
	end
	eq(Formula.petPower("Doggy", 3), Pets.Doggy.Power * Config.Tiers[3].Multiplier, "Diamond power")
	eq(Formula.tier(nil), 1, "missing tier is Normal")
	eq(Formula.tier(99), #Config.Tiers, "tier is capped")
	eq(Formula.tier(0), 1, "tier has a floor")
end)

-- Odds ---------------------------------------------------------------------------------------

test("odds always sum to 100% and luck only helps rare pets", function()
	for _, egg in Eggs.List do
		local base = Formula.eggOdds(egg.Id, 1)
		for _, luck in { 1, 1.5, 2, 4.5 } do
			local total = 0
			for _, entry in Formula.eggOdds(egg.Id, luck) do
				total += entry.Chance
			end
			near(total, 1, 1e-9, egg.Id .. " total at luck " .. luck)
		end
		local lucky = Formula.eggOdds(egg.Id, 2)
		for index, entry in base do
			local rarity = Config.Rarities[Pets[entry.Id].Rarity]
			if rarity.Lucky then
				assert(lucky[index].Chance > entry.Chance, egg.Id .. " " .. entry.Id .. " should improve with luck")
			else
				assert(lucky[index].Chance < entry.Chance, egg.Id .. " " .. entry.Id .. " should shrink with luck")
			end
		end
	end
end)

test("rolls match the displayed odds", function()
	local rng = Random.new(42)
	local counts = {}
	local rolls = 200000
	for _ = 1, rolls do
		local petId = Formula.rollEgg("Meadow", 1, rng)
		counts[petId] = (counts[petId] or 0) + 1
	end
	for _, entry in Formula.eggOdds("Meadow", 1) do
		near((counts[entry.Id] or 0) / rolls, entry.Chance, 0.006, entry.Id)
	end
end)

-- Economy ------------------------------------------------------------------------------------

test("a brand new player earns 1 coin per tap", function()
	eq(Formula.tapValue(freshData(), freshSession()), 1, "tap value")
end)

test("multipliers stack as documented", function()
	local data = freshData()
	data.Upgrades.TapPower = 4 -- 5 base
	data.Rebirths = 2 -- x2
	data.HighestZone = 2 -- x1.5
	data.Pets = {
		p1 = { Id = "Doggy", Tier = 1, Equipped = true }, -- +0.2
		p2 = { Id = "Kitty", Tier = 2, Equipped = true }, -- +0.35 * 3 (Golden)
		p3 = { Id = "Bunny", Tier = 1, Equipped = false }, -- not equipped
	}
	local session = freshSession()
	local expected = 5 * (1 + 0.2 + 1.05) * 2 * 1.5
	near(Formula.tapValue(data, session), expected, 1e-9, "no passes")

	session.Passes.DoubleCoins = true
	session.Passes.VIP = true
	near(Formula.tapValue(data, session), expected * 2 * 1.25, 1e-9, "with passes")

	data.Boosts.Coins = 30
	session.FriendBonus = 0.2
	near(Formula.tapValue(data, session), expected * 2 * 1.25 * 2 * 1.2, 1e-9, "with boost and friends")
	near(Formula.baseTapValue(data, session), expected * 2 * 1.25, 1e-9, "base ignores temporary bonuses")
end)

test("equip slots and luck include upgrades and passes", function()
	local data = freshData()
	local session = freshSession()
	eq(Formula.equipSlots(data, session), 3, "base slots")
	data.Upgrades.PetSlots = 2
	session.Passes.VIP = true
	session.Passes.ExtraPets = true
	eq(Formula.equipSlots(data, session), 3 + 2 + 1 + 3, "all slots")

	eq(Formula.luck(data, session), 1, "base luck")
	data.Upgrades.Luck = 5
	session.Passes.Lucky = true
	data.Boosts.Luck = 10
	near(Formula.luck(data, session), (1 + 0.5 + 0.25) * 2, 1e-9, "stacked luck")
end)

test("upgrade costs grow and stop at max level", function()
	for _, upgrade in Upgrades.List do
		local previous = 0
		for level = 0, upgrade.MaxLevel - 1 do
			local cost = Formula.upgradeCost(upgrade.Id, level)
			assert(cost and cost > previous, upgrade.Id .. " cost at level " .. level)
			previous = cost :: number
		end
		eq(Formula.upgradeCost(upgrade.Id, upgrade.MaxLevel), nil, upgrade.Id .. " past max")
	end
end)

test("rebirth cost and gems grow each rebirth", function()
	for rebirths = 0, 20 do
		assert(Formula.rebirthCost(rebirths + 1) > Formula.rebirthCost(rebirths), "cost " .. rebirths)
		assert(Formula.rebirthGems(rebirths + 1) > Formula.rebirthGems(rebirths), "gems " .. rebirths)
	end
end)

test("quests start with sensible goals", function()
	local data = freshData()
	for _, template in Quests.Templates do
		local goal = template.Goal(data, freshSession())
		assert(goal > 0, template.Stat .. " goal")
		local quest = { Stat = template.Stat, Goal = goal, Start = 0, Gems = template.Gems }
		eq(Quests.progress(data, quest), 0, template.Stat .. " starts at 0")
		data.Stats[template.Stat] = goal * 2
		eq(Quests.progress(data, quest), goal, template.Stat .. " progress is capped at the goal")
	end
end)

test("luck levels come from clover XP and stack with other luck", function()
	eq(Formula.luckLevel(0), 0, "no XP")
	local previous = 0
	for level = 1, Config.Luck.MaxLevel do
		local needed = Formula.luckXPForLevel(level)
		assert(needed > previous, "XP needed grows at level " .. level)
		eq(Formula.luckLevel(needed), level, "exactly enough XP for level " .. level)
		eq(Formula.luckLevel(needed - 1), level - 1, "one XP short of level " .. level)
		previous = needed
	end
	eq(Formula.luckLevel(1e12), Config.Luck.MaxLevel, "level is capped")

	local data = freshData()
	local session = freshSession()
	data.LuckXP = Formula.luckXPForLevel(10)
	near(Formula.luck(data, session), 1 + 10 * Config.Luck.PerLevel, 1e-9, "luck from level")
	data.Upgrades.Luck = 2
	session.Passes.Lucky = true
	data.Boosts.Luck = 5
	local breakdown = Formula.luckBreakdown(data, session)
	eq(breakdown.Level, 10, "breakdown level")
	near(breakdown.Total, (1 + 10 * Config.Luck.PerLevel + 0.2 + 0.25) * 2, 1e-9, "stacked luck")
end)

test("clovers give luck XP that grows by area, never coins", function()
	for index, zone in Zones.List do
		assert(zone.CloverValue > 0, "area " .. index .. " clover value")
		if index > 1 then
			assert(zone.CloverValue >= Zones.List[index - 1].CloverValue, "area " .. index .. " clovers get better")
		end
		eq(Formula.cloverValue(index, false), zone.CloverValue, "normal clover")
		eq(Formula.cloverValue(index, true), zone.CloverValue * Config.Orbs.LuckyMultiplier, "lucky clover")
	end
	eq((Formula :: any).orbValue, nil, "orbs no longer pay coins")
end)

-- Daily streak ---------------------------------------------------------------------------------

test("daily rewards advance, wrap after a week and reset after a missed day", function()
	local hour = 3600
	local now = 1_000_000
	local daily = { Last = 0, Streak = 0 }

	local canClaim, day, _, streak = Formula.dailyStatus(daily, now)
	eq(canClaim, true, "new player can claim")
	eq(day, 1, "new player day")

	-- Claim 7 days in a row, 21 hours apart.
	for expectedDay = 1, 7 do
		canClaim, day, _, streak = Formula.dailyStatus(daily, now)
		eq(canClaim, true, "claimable on day " .. expectedDay)
		eq(day, expectedDay, "day number")
		daily = { Last = now, Streak = streak + 1 }
		local again = Formula.dailyStatus(daily, now + hour)
		eq(again, false, "not claimable twice in a day")
		now += 21 * hour
	end
	canClaim, day = Formula.dailyStatus(daily, now)
	eq(canClaim, true, "claimable after a full week")
	eq(day, 1, "wraps back to day 1")

	daily = { Last = now, Streak = 3 }
	canClaim, day, _, streak = Formula.dailyStatus(daily, now + 49 * hour)
	eq(canClaim, true, "claimable after missing a day")
	eq(day, 1, "streak resets")
	eq(streak, 0, "streak count resets")
end)

-- Formatting ---------------------------------------------------------------------------------

test("numbers are abbreviated", function()
	local cases = {
		{ 0, "0" },
		{ 7, "7" },
		{ 0.35, "0.35" },
		{ 1.5, "1.5" },
		{ 999, "999" },
		{ 1000, "1K" },
		{ 1234, "1.23K" },
		{ 12345, "12.3K" },
		{ 123456, "123K" },
		{ 1_000_000, "1M" },
		{ 2_500_000_000, "2.5B" },
		{ 25e12, "25T" },
		{ -1500, "-1.5K" },
	}
	for _, case in cases do
		eq(Format.number(case[1]), case[2], "Format.number(" .. case[1] .. ")")
	end
end)

test("chances, times and commas format nicely", function()
	eq(Format.chance(0.62), "62%", "62%")
	eq(Format.chance(0.019), "1.9%", "1.9%")
	eq(Format.chance(0.001), "0.1%", "0.1%")
	eq(Format.chance(0.00001), "0.001%", "0.001%")
	eq(Format.time(65), "1:05", "minutes")
	eq(Format.time(3725), "1:02:05", "hours")
	eq(Format.time(90000), "1d 1h", "days")
	eq(Format.commas(1234567), "1,234,567", "commas")
	eq(Format.commas(123), "123", "short commas")
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
