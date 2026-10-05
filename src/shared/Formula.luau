--!strict
--[[
	Every game-rule calculation, shared so the client can preview exactly what the server grants.
	`data` is the saved profile; `session` holds per-server state (passes, premium, friend bonus).
]]

local Config = require(script.Parent.Config)
local Eggs = require(script.Parent.Eggs)
local Pets = require(script.Parent.Pets)
local Upgrades = require(script.Parent.Upgrades)
local Zones = require(script.Parent.Zones)

local Formula = {}

function Formula.level(data, upgradeId: string): number
	return data.Upgrades[upgradeId] or 0
end

function Formula.upgradeCost(upgradeId: string, level: number): number?
	local upgrade = Upgrades.ById[upgradeId]
	if not upgrade or level >= upgrade.MaxLevel then
		return nil
	end
	if upgrade.Costs then
		return upgrade.Costs[level + 1]
	end
	return math.floor((upgrade.BaseCost :: number) * (upgrade.Growth :: number) ^ level)
end

function Formula.tapPower(level: number): number
	return 1 + level
end

-- A pet's tier (1 = Normal … #Config.Tiers). Missing or invalid tiers count as Normal.
function Formula.tier(tier: number?): number
	return math.clamp(math.floor(tonumber(tier) or 1), 1, #Config.Tiers)
end

-- A pet's level (1 … Config.PetLevels.MaxLevel). Missing or invalid levels count as 1.
function Formula.petLevel(level: number?): number
	return math.clamp(math.floor(tonumber(level) or 1), 1, Config.PetLevels.MaxLevel)
end

function Formula.levelMultiplier(level: number?): number
	return 1 + (Formula.petLevel(level) - 1) * Config.PetLevels.PowerPerLevel
end

function Formula.petPower(petId: string, tier: number?, level: number?): number
	local pet = Pets[petId]
	if not pet then
		return 0
	end
	return pet.Power * Config.Tiers[Formula.tier(tier)].Multiplier * Formula.levelMultiplier(level)
end

function Formula.petBonus(data): number
	local total = 0
	for _, pet in data.Pets do
		if pet.Equipped then
			total += Formula.petPower(pet.Id, pet.Tier, pet.Level)
		end
	end
	return total
end

function Formula.rebirthMultiplier(rebirths: number): number
	return 1 + rebirths * Config.Rebirth.MultiplierPerRebirth
end

-- True once every pet in an egg's table has been discovered (that area's Pet Index is complete).
function Formula.eggIndexComplete(data, eggId: string): boolean
	local egg = Eggs.ById[eggId]
	if not egg then
		return false
	end
	for _, entry in egg.Pets do
		if not data.Index[entry.Id] then
			return false
		end
	end
	return true
end

-- Permanent coin bonus from completed area Pet Indexes, Config.Bonuses.AreaIndexCoinBonus each.
function Formula.areaIndexBonus(data): number
	local completed = 0
	for _, egg in Eggs.List do
		if Formula.eggIndexComplete(data, egg.Id) then
			completed += 1
		end
	end
	return completed * Config.Bonuses.AreaIndexCoinBonus
end

function Formula.masteryMultiplier(level: number): number
	return 1 + level * 0.1
end

function Formula.zoneMultiplier(data): number
	local zone = Zones.List[data.HighestZone] or Zones.List[1]
	return zone.TapMultiplier
end

-- Multiplier from passes and Premium, applied to everything the player earns.
function Formula.passMultiplier(session): number
	local multiplier = 1
	if session.Passes.VIP then
		multiplier *= Config.Bonuses.VIPCoinMultiplier
	end
	if session.Passes.DoubleCoins then
		multiplier *= Config.Bonuses.DoubleCoinsMultiplier
	end
	if session.Premium then
		multiplier *= 1 + Config.Bonuses.PremiumCoinBonus
	end
	return multiplier
end

-- Temporary multipliers: boosts and friends in the server.
function Formula.temporaryMultiplier(data, session): number
	local multiplier = 1 + (session.FriendBonus or 0)
	if (data.Boosts.Coins or 0) > 0 then
		multiplier *= Config.Bonuses.CoinBoostMultiplier
	end
	return multiplier
end

function Formula.coinMultiplier(data, session, includeTemporary: boolean): number
	local multiplier = (1 + Formula.petBonus(data))
		* (1 + Formula.areaIndexBonus(data))
		* Formula.rebirthMultiplier(data.Rebirths)
		* Formula.zoneMultiplier(data)
		* Formula.masteryMultiplier(Formula.level(data, "CoinMastery"))
		* Formula.passMultiplier(session)
	if includeTemporary then
		multiplier *= Formula.temporaryMultiplier(data, session)
	end
	return multiplier
end

function Formula.tapValue(data, session): number
	return Formula.tapPower(Formula.level(data, "TapPower")) * Formula.coinMultiplier(data, session, true)
end

-- Tap value without boosts or friends, used to size rewards and coin packs so they stay stable.
function Formula.baseTapValue(data, session): number
	return Formula.tapPower(Formula.level(data, "TapPower")) * Formula.coinMultiplier(data, session, false)
end

-- Luck XP from one clover in an area.
function Formula.cloverValue(zoneIndex: number, lucky: boolean): number
	local zone = Zones.List[zoneIndex] or Zones.List[1]
	return zone.CloverValue * (if lucky then Config.Orbs.LuckyMultiplier else 1)
end

-- Multiplier from a clover-grabbing streak (see Config.Orbs.StreakWindowSeconds): grows by
-- StreakStep per clover grabbed in quick succession, capped at StreakMaxMultiplier.
function Formula.cloverStreakMultiplier(streak: number): number
	return math.min(1 + math.max(streak, 0) * Config.Orbs.StreakStep, Config.Orbs.StreakMaxMultiplier)
end

-- Coins for time away (Config.Offline): Rate of your normal earning rate for up to MaxHours
-- away. Absences shorter than MinSeconds (a reconnect, a server hop) earn nothing.
function Formula.offlineCoins(data, session, awaySeconds: number): number
	if awaySeconds < Config.Offline.MinSeconds then
		return 0
	end
	local counted = math.min(awaySeconds, Config.Offline.MaxHours * 3600)
	return Formula.rewardCoins(data, session, counted * Config.Offline.Rate)
end

-- Total Luck XP needed to reach a Luck level.
function Formula.luckXPForLevel(level: number): number
	return math.ceil(Config.Luck.BaseXP * level ^ Config.Luck.Exponent)
end

function Formula.luckLevel(xp: number): number
	local level = math.floor((math.max(xp, 0) / Config.Luck.BaseXP) ^ (1 / Config.Luck.Exponent))
	-- Correct for floating point at exact boundaries.
	while level > 0 and Formula.luckXPForLevel(level) > xp do
		level -= 1
	end
	while Formula.luckXPForLevel(level + 1) <= xp do
		level += 1
	end
	return level
end

-- The highest Luck level a player with this many rebirths can reach. It keeps rising with every
-- rebirth; there is no overall maximum.
function Formula.luckCap(rebirths: number?): number
	return Config.Luck.StartCap + math.max(rebirths or 0, 0) * Config.Luck.CapPerRebirth
end

-- A player's Luck level: their clover XP level, held down to the cap their rebirths allow.
function Formula.luckLevelOf(data): number
	return math.min(Formula.luckLevel(data.LuckXP or 0), Formula.luckCap(data.Rebirths))
end

-- Coins equal to `seconds` of tapping at the estimated tap rate.
function Formula.rewardCoins(data, session, seconds: number): number
	return math.max(50, math.floor(Formula.baseTapValue(data, session) * Config.Tap.EstimatedPerSecond * seconds))
end

function Formula.equipSlots(data, session): number
	local slots = Config.Pets.BaseEquipSlots + Formula.level(data, "PetSlots")
	if session.Passes.VIP then
		slots += Config.Bonuses.VIPExtraSlots
	end
	if session.Passes.ExtraPets then
		slots += Config.Bonuses.ExtraPetsPassSlots
	end
	return slots
end

function Formula.petCount(data): number
	local count = 0
	for _ in data.Pets do
		count += 1
	end
	return count
end

export type LuckBreakdown = {
	Level: number,
	FromLevel: number,
	FromUpgrade: number,
	FromPass: number,
	BoostMultiplier: number,
	Total: number,
}

-- Where the player's luck comes from. Luck multiplies the weight of Rare-and-better pets.
function Formula.luckBreakdown(data, session): LuckBreakdown
	local level = Formula.luckLevelOf(data)
	local fromLevel = level * Config.Luck.PerLevel
	local fromUpgrade = Formula.level(data, "Luck") * 0.1
	local fromPass = if session.Passes.Lucky then Config.Bonuses.LuckyPassLuck else 0
	local boost = if (data.Boosts.Luck or 0) > 0 then Config.Bonuses.LuckBoostMultiplier else 1
	return {
		Level = level,
		FromLevel = fromLevel,
		FromUpgrade = fromUpgrade,
		FromPass = fromPass,
		BoostMultiplier = boost,
		Total = (1 + fromLevel + fromUpgrade + fromPass) * boost,
	}
end

function Formula.luck(data, session): number
	return Formula.luckBreakdown(data, session).Total
end

export type Odds = { { Id: string, Chance: number } }

-- The exact probabilities used by rollEgg, after luck. This is what players see on every egg.
-- guaranteeLucky zeroes out every non-Rare-or-better pet's weight (see Formula.rollHatch).
function Formula.eggOdds(eggId: string, luck: number, guaranteeLucky: boolean?): Odds
	local egg = Eggs.ById[eggId]
	local weights = {}
	local total = 0
	for _, entry in egg.Pets do
		local rarity = Config.Rarities[Pets[entry.Id].Rarity]
		local weight = if guaranteeLucky and not rarity.Lucky
			then 0
			else entry.Weight * (if rarity.Lucky then luck else 1)
		table.insert(weights, weight)
		total += weight
	end
	local odds = {}
	for index, entry in egg.Pets do
		table.insert(odds, { Id = entry.Id, Chance = weights[index] / total })
	end
	return odds
end

-- Picks an index from a list of chances that sum to 1.
local function pick(chances: { number }, rng: Random): number
	local roll = rng:NextNumber()
	for index, chance in chances do
		roll -= chance
		if roll <= 0 then
			return index
		end
	end
	return 1
end

-- Turns weights (worst outcome first) into chances, with luck favouring the best outcomes:
-- weight i is multiplied by luck ^ ((i - 1) / (#weights - 1)). See Config.Hatch.
local function luckyChances(weights: { number }, luck: number): { number }
	local top = math.max(#weights - 1, 1)
	local scaled = {}
	local total = 0
	for index, weight in weights do
		local value = weight * luck ^ ((index - 1) / top)
		scaled[index] = value
		total += value
	end
	for index, value in scaled do
		scaled[index] = value / total
	end
	return scaled
end

function Formula.rollEgg(eggId: string, luck: number, rng: Random, guaranteeLucky: boolean?): string
	local odds = Formula.eggOdds(eggId, luck, guaranteeLucky)
	local chances = {}
	for index, entry in odds do
		chances[index] = entry.Chance
	end
	return odds[pick(chances, rng)].Id
end

-- Chance of hatching each tier (index = tier), after luck. Shown on every egg.
function Formula.tierOdds(luck: number): { number }
	local weights = {}
	for index, tier in Config.Tiers do
		weights[index] = tier.HatchWeight
	end
	return luckyChances(weights, luck)
end

-- Chance of hatching at each level (index = level), after luck. Shown on every egg.
function Formula.levelOdds(luck: number): { number }
	return luckyChances(Config.Hatch.LevelWeights, luck)
end

export type Hatch = { Id: string, Tier: number, Level: number }

-- One hatch = three separate rolls: the pet, its tier and its level. guaranteeLucky (hatch pity,
-- see Config.Hatch.PityMisses) restricts the pet roll to Rare-or-better pets; tier and level are
-- unaffected.
function Formula.rollHatch(eggId: string, luck: number, rng: Random, guaranteeLucky: boolean?): Hatch
	return {
		Id = Formula.rollEgg(eggId, luck, rng, guaranteeLucky),
		Tier = pick(Formula.tierOdds(luck), rng),
		Level = pick(Formula.levelOdds(luck), rng),
	}
end

function Formula.rebirthCost(rebirths: number): number
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ rebirths)
end

function Formula.rebirthGems(rebirths: number): number
	return Config.Rebirth.BaseGems + Config.Rebirth.GemsPerRebirth * rebirths
end

function Formula.magnetRadius(data): number
	return Config.Orbs.BaseMagnetRadius + Config.Orbs.MagnetPerLevel * Formula.level(data, "Magnet")
end

function Formula.walkSpeed(data): number
	return Config.WalkSpeed.Base + Config.WalkSpeed.PerLevel * Formula.level(data, "WalkSpeed")
end

-- Human-readable effect of an upgrade at a given level ("x12 per tap", "+30% luck").
function Formula.upgradeEffect(upgradeId: string, level: number): string
	if upgradeId == "TapPower" then
		return tostring(Formula.tapPower(level)) .. " base / tap"
	elseif upgradeId == "Magnet" then
		return tostring(Config.Orbs.BaseMagnetRadius + Config.Orbs.MagnetPerLevel * level) .. " stud range"
	elseif upgradeId == "WalkSpeed" then
		return tostring(Config.WalkSpeed.Base + Config.WalkSpeed.PerLevel * level) .. " speed"
	elseif upgradeId == "PetSlots" then
		return "+" .. level .. " slots"
	elseif upgradeId == "Luck" then
		return "+" .. (level * 10) .. "% luck"
	elseif upgradeId == "CoinMastery" then
		return "+" .. (level * 10) .. "% coins"
	end
	return tostring(level)
end

-- Daily reward state: can the player claim now, which day (1-7) they'd get, seconds until ready,
-- and the streak so far (reset to 0 once a day is missed).
function Formula.dailyStatus(daily, now: number): (boolean, number, number, number)
	local cooldown = Config.Daily.CooldownHours * 3600
	local sinceLast = now - daily.Last
	local streak = daily.Streak
	if daily.Last == 0 or sinceLast > Config.Daily.StreakResetHours * 3600 then
		streak = 0
	end
	local day = (streak % #Config.Daily.Rewards) + 1
	if daily.Last == 0 or sinceLast >= cooldown then
		return true, day, 0, streak
	end
	return false, day, cooldown - sinceLast, streak
end

return Formula
