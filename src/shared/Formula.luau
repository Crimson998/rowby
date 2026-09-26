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

function Formula.petPower(petId: string, tier: number?): number
	local pet = Pets[petId]
	if not pet then
		return 0
	end
	return pet.Power * Config.Tiers[Formula.tier(tier)].Multiplier
end

function Formula.petBonus(data): number
	local total = 0
	for _, pet in data.Pets do
		if pet.Equipped then
			total += Formula.petPower(pet.Id, pet.Tier)
		end
	end
	return total
end

function Formula.rebirthMultiplier(rebirths: number): number
	return 1 + rebirths * Config.Rebirth.MultiplierPerRebirth
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
	while level < Config.Luck.MaxLevel and Formula.luckXPForLevel(level + 1) <= xp do
		level += 1
	end
	return math.min(level, Config.Luck.MaxLevel)
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
	local level = Formula.luckLevel(data.LuckXP or 0)
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
function Formula.eggOdds(eggId: string, luck: number): Odds
	local egg = Eggs.ById[eggId]
	local weights = {}
	local total = 0
	for _, entry in egg.Pets do
		local rarity = Config.Rarities[Pets[entry.Id].Rarity]
		local weight = entry.Weight * (if rarity.Lucky then luck else 1)
		table.insert(weights, weight)
		total += weight
	end
	local odds = {}
	for index, entry in egg.Pets do
		table.insert(odds, { Id = entry.Id, Chance = weights[index] / total })
	end
	return odds
end

function Formula.rollEgg(eggId: string, luck: number, rng: Random): string
	local odds = Formula.eggOdds(eggId, luck)
	local roll = rng:NextNumber()
	for _, entry in odds do
		roll -= entry.Chance
		if roll <= 0 then
			return entry.Id
		end
	end
	return odds[1].Id
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
