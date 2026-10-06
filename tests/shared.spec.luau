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
		Weekly = { Quests = {}, Start = 0 },
		LastSeen = 0,
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

test("live codes are sanitized and clamped", function()
	eq(Rewards.sanitize(nil), nil, "non-table")
	eq(Rewards.sanitize({}), nil, "empty reward")
	eq(Rewards.sanitize({ Gems = 0, Pet = "Dog" }), nil, "unknown or zero fields grant nothing")
	local reward = Rewards.sanitize({ Gems = "25.7", CoinBoostMinutes = 1e9, Pet = "Dog" }) :: any
	eq(reward.Gems, 25, "string values are floored")
	eq(reward.CoinBoostMinutes, Rewards.LiveLimits.CoinBoostMinutes, "clamped to the limit")
	eq(reward.Pet, nil, "unknown field dropped")
end)

test("weekly quests scale up daily quest templates", function()
	assert(Config.Weekly.Slots > 0, "weekly slots")
	assert(Config.Weekly.PeriodDays > 0, "weekly period")
	assert(Config.Weekly.GoalMultiplier > 1, "weekly goals must be bigger than daily")
	assert(Config.Weekly.GemMultiplier > 1, "weekly rewards must be bigger than daily")
	assert(Config.Weekly.Slots <= #Quests.Templates, "not enough templates to fill weekly slots without repeats")
end)

test("offline earnings pay less than playing, and are capped", function()
	assert(Config.Offline.Rate > 0 and Config.Offline.Rate < 1, "offline rate must be a fraction of active play")
	assert(Config.Offline.MaxHours > 0, "offline cap")
	assert(Config.Offline.MinSeconds >= 0, "offline minimum away time")
	local data = freshData()
	local session = freshSession()
	local capped = Config.Offline.MaxHours * 3600 * Config.Offline.Rate
	local uncapped = (Config.Offline.MaxHours + 1) * 3600 * Config.Offline.Rate
	assert(
		Formula.rewardCoins(data, session, uncapped) > Formula.rewardCoins(data, session, capped),
		"more away time pays more up to the cap"
	)
end)

test("offline coins need a real absence and stop growing at the cap", function()
	local data = freshData()
	local session = freshSession()
	local offline = Config.Offline
	eq(Formula.offlineCoins(data, session, offline.MinSeconds - 1), 0, "short disconnects earn nothing")
	assert(Formula.offlineCoins(data, session, offline.MinSeconds) > 0, "a real absence earns coins")
	local cap = Formula.offlineCoins(data, session, offline.MaxHours * 3600)
	eq(Formula.offlineCoins(data, session, offline.MaxHours * 3600 * 10), cap, "longer than the cap earns the cap")
	eq(Formula.offlineCoins(data, session, math.huge), cap, "the most you can be owed is the cap")
	eq(
		cap,
		Formula.rewardCoins(data, session, offline.MaxHours * 3600 * offline.Rate),
		"the cap is Rate of that much play"
	)
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

test("pet levels multiply power and stay in range", function()
	eq(Formula.petLevel(nil), 1, "missing level is 1")
	eq(Formula.petLevel(0), 1, "level has a floor")
	eq(Formula.petLevel(1e9), Config.PetLevels.MaxLevel, "level is capped")
	eq(Formula.levelMultiplier(1), 1, "level 1 adds nothing")
	near(
		Formula.petPower("Doggy", 2, 5),
		Pets.Doggy.Power * Config.Tiers[2].Multiplier * (1 + 4 * Config.PetLevels.PowerPerLevel),
		1e-9,
		"Golden level 5 power"
	)
	assert(#Config.Hatch.LevelWeights <= Config.PetLevels.MaxLevel, "hatch levels must fit under the max level")
	local data = { Pets = { a = { Id = "Doggy", Tier = 1, Level = 3, Equipped = true } } }
	near(Formula.petBonus(data), Formula.petPower("Doggy", 1, 3), 1e-9, "equipped bonus uses the level")
end)

-- Odds ---------------------------------------------------------------------------------------

test("pet set bonuses count distinct pets per area and add across areas", function()
	local data = freshData()
	local pieces, step = Formula.setProgress(data, "Meadow")
	eq(pieces, 0, "nothing equipped")
	eq(step, nil, "no step yet")
	data.Pets = {
		a = { Id = "Doggy", Tier = 1, Level = 1, Equipped = true },
		b = { Id = "Doggy", Tier = 2, Level = 1, Equipped = true },
		c = { Id = "Kitty", Tier = 1, Level = 1, Equipped = false },
	}
	pieces, step = Formula.setProgress(data, "Meadow")
	eq(pieces, 1, "copies of one pet count once, unequipped pets not at all")
	eq(step, nil, "one piece is no bonus")
	data.Pets.c.Equipped = true
	local coins = Formula.setBonus(data)
	near(coins, Config.SetBonuses[1].Coins, 1e-9, "two pieces unlock the first step")
	near(
		Formula.coinMultiplier(data, freshSession(), false) / Formula.coinMultiplier(freshData(), freshSession(), false),
		(1 + Formula.petBonus(data)) * (1 + coins),
		1e-9,
		"set bonus multiplies coins"
	)
	local candy = Eggs.ById.Candy.Pets
	data.Pets.d = { Id = candy[1].Id, Tier = 1, Level = 1, Equipped = true }
	data.Pets.e = { Id = candy[2].Id, Tier = 1, Level = 1, Equipped = true }
	near(Formula.setBonus(data), coins + Config.SetBonuses[1].Coins, 1e-9, "different areas add together")
end)

test("set bonus steps only grow and luck feeds the total", function()
	local previous = 0
	for _, step in Config.SetBonuses do
		assert(step.Pieces > previous, "pieces must increase")
		previous = step.Pieces
	end
	for _, egg in Eggs.List do
		assert(#egg.Pets >= previous, egg.Id .. " has too few pets for the top set step")
	end
	local data = freshData()
	local fullEgg = Eggs.List[1]
	for index, entry in fullEgg.Pets do
		data.Pets["p" .. index] = { Id = entry.Id, Tier = 1, Level = 1, Equipped = true }
	end
	local _, luckBonus = Formula.setBonus(data)
	assert(luckBonus > 0, "a full set grants luck")
	near(Formula.luckBreakdown(data, freshSession()).FromSets, luckBonus, 1e-9, "luck breakdown")
end)

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

test("tier and level odds sum to 100% and luck favours the top", function()
	for _, luck in { 1, 1.5, 3, 12 } do
		for label, odds in { tiers = Formula.tierOdds(luck), levels = Formula.levelOdds(luck) } do
			local total = 0
			for _, chance in odds do
				total += chance
			end
			near(total, 1, 1e-9, label .. " total at luck " .. luck)
		end
	end
	for label, pair in
		{
			tiers = { Formula.tierOdds(1), Formula.tierOdds(3) },
			levels = { Formula.levelOdds(1), Formula.levelOdds(3) },
		}
	do
		local base, lucky = pair[1], pair[2]
		assert(lucky[1] < base[1], label .. ": luck should make the lowest outcome less likely")
		assert(lucky[#lucky] > base[#base], label .. ": luck should make the best outcome more likely")
		-- The best outcome gains the most, relatively.
		local topGain = lucky[#lucky] / base[#base]
		for index = 2, #base - 1 do
			assert(lucky[index] / base[index] <= topGain + 1e-9, label .. " " .. index .. " gains more than the top")
		end
	end
	-- With no luck, the chances are exactly the configured weights.
	local totalWeight = 0
	for _, tier in Config.Tiers do
		totalWeight += tier.HatchWeight
	end
	near(Formula.tierOdds(1)[2], Config.Tiers[2].HatchWeight / totalWeight, 1e-12, "Golden chance at luck 1")
	for index = 2, #Config.Tiers do
		assert(Config.Tiers[index].HatchWeight < Config.Tiers[index - 1].HatchWeight, "higher tiers must be rarer")
	end
	for index = 2, #Config.Hatch.LevelWeights do
		assert(Config.Hatch.LevelWeights[index] < Config.Hatch.LevelWeights[index - 1], "higher levels must be rarer")
	end
end)

test("a hatch rolls pet, tier and level separately, matching the shown odds", function()
	local rng = Random.new(7)
	local rolls = 200000
	local tiers, levels = {}, {}
	for _ = 1, rolls do
		local hatch = Formula.rollHatch("Frost", 2, rng)
		assert(Pets[hatch.Id], "unknown pet " .. tostring(hatch.Id))
		tiers[hatch.Tier] = (tiers[hatch.Tier] or 0) + 1
		levels[hatch.Level] = (levels[hatch.Level] or 0) + 1
	end
	for tier, chance in Formula.tierOdds(2) do
		near((tiers[tier] or 0) / rolls, chance, 0.004, "tier " .. tier)
	end
	for level, chance in Formula.levelOdds(2) do
		near((levels[level] or 0) / rolls, chance, 0.004, "level " .. level)
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

-- Hatch pity ----------------------------------------------------------------------------------

test("a guaranteed roll only ever gives Rare-or-better pets, still summing to 100%", function()
	for _, egg in Eggs.List do
		for _, luck in { 1, 2, 4.5 } do
			local total = 0
			for _, entry in Formula.eggOdds(egg.Id, luck, true) do
				local rarity = Config.Rarities[Pets[entry.Id].Rarity]
				if rarity.Lucky then
					assert(entry.Chance > 0, egg.Id .. " " .. entry.Id .. " should still be possible")
				else
					eq(entry.Chance, 0, egg.Id .. " " .. entry.Id .. " must be excluded by the guarantee")
				end
				total += entry.Chance
			end
			near(total, 1, 1e-9, egg.Id .. " guaranteed total at luck " .. luck)
		end
	end
end)

test("rollEgg never returns a Common or Uncommon pet once guaranteed", function()
	local rng = Random.new(11)
	for _ = 1, 2000 do
		local petId = Formula.rollEgg("Meadow", 1, rng, true)
		local rarity = Config.Rarities[Pets[petId].Rarity]
		assert(rarity.Lucky, "guaranteed roll gave " .. petId .. " (" .. Pets[petId].Rarity .. ")")
	end
end)

-- Clover streaks -------------------------------------------------------------------------------

test("clover streak multiplier grows with streak and caps out", function()
	eq(Formula.cloverStreakMultiplier(0), 1, "no streak")
	near(Formula.cloverStreakMultiplier(1), 1 + Config.Orbs.StreakStep, 1e-9, "one streak")
	near(Formula.cloverStreakMultiplier(5), 1 + 5 * Config.Orbs.StreakStep, 1e-9, "five streak")
	eq(Formula.cloverStreakMultiplier(1000), Config.Orbs.StreakMaxMultiplier, "caps at the max")
	assert(Config.Orbs.StreakMaxMultiplier > 1, "cap must allow some bonus")
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
	local expected = 5 * (1 + 0.2 + 1.05) * (1 + Config.SetBonuses[1].Coins) * 2 * 1.5 -- Doggy + Kitty: 2-piece Meadow set
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

test("area Pet Index bonus applies once every pet in an area is discovered", function()
	local data = freshData()
	local session = freshSession()
	eq(Formula.areaIndexBonus(data), 0, "nothing discovered yet")
	eq(Formula.eggIndexComplete(data, "Meadow"), false, "Meadow incomplete")

	for _, entry in Eggs.ById.Meadow.Pets do
		data.Index[entry.Id] = true
	end
	eq(Formula.eggIndexComplete(data, "Meadow"), true, "Meadow complete")
	eq(Formula.eggIndexComplete(data, "Candy"), false, "Candy still incomplete")
	near(Formula.areaIndexBonus(data), Config.Bonuses.AreaIndexCoinBonus, 1e-9, "one area complete")

	for _, entry in Eggs.ById.Candy.Pets do
		data.Index[entry.Id] = true
	end
	near(Formula.areaIndexBonus(data), Config.Bonuses.AreaIndexCoinBonus * 2, 1e-9, "two areas complete")
	near(
		Formula.coinMultiplier(data, session, false),
		1 + Config.Bonuses.AreaIndexCoinBonus * 2,
		1e-9,
		"bonus feeds the coin multiplier"
	)
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
	for level = 1, 400 do
		local needed = Formula.luckXPForLevel(level)
		assert(needed > previous, "XP needed grows at level " .. level)
		eq(Formula.luckLevel(needed), level, "exactly enough XP for level " .. level)
		eq(Formula.luckLevel(needed - 1), level - 1, "one XP short of level " .. level)
		previous = needed
	end
	assert(Formula.luckLevel(1e12) > 400, "clover XP levels have no maximum")

	eq(Formula.luckCap(0), Config.Luck.StartCap, "cap before any rebirth")
	eq(Formula.luckCap(1), Config.Luck.StartCap + Config.Luck.CapPerRebirth, "each rebirth raises the cap")
	eq(
		Formula.luckCap(100),
		Config.Luck.StartCap + 100 * Config.Luck.CapPerRebirth,
		"the cap keeps rising with no maximum"
	)
	local capped = freshData()
	capped.LuckXP = Formula.luckXPForLevel(200)
	eq(Formula.luckLevelOf(capped), Config.Luck.StartCap, "level held at the cap")
	capped.Rebirths = 1
	eq(Formula.luckLevelOf(capped), Config.Luck.StartCap + Config.Luck.CapPerRebirth, "rebirth lifts the cap")

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
	eq(Format.duration(45), "45s", "duration seconds")
	eq(Format.duration(750), "12m", "duration minutes")
	eq(Format.duration(18720), "5h 12m", "duration hours")
	eq(Format.duration(10800), "3h", "duration whole hours")
	eq(Format.duration(190800), "2d 5h", "duration days")
	eq(Format.commas(1234567), "1,234,567", "commas")
	eq(Format.commas(123), "123", "short commas")
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
