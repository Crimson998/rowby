--[[
	Hatching, inventory, equipping, locking, tier crafting, bulk clean-up and the pet index.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Eggs = require(Shared.Eggs)
local Format = require(Shared.Format)
local Formula = require(Shared.Formula)
local Net = require(Shared.Net)
local Pets = require(Shared.Pets)
local Zones = require(Shared.Zones)

local Actions = require(script.Parent.Parent.Actions)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

local PetService = {}

local MAX_BATCH = 200
-- Hatching this tier or better (Emerald+) is announced to the server, whatever the rarity.
-- Diamond (about 1 in 90 hatches) would flood the chat.
local ANNOUNCE_TIER = 4

local rng = Random.new()
local hatchedRemote = Net.event("Hatched")
local announceRemote = Net.event("Announce")

local function refreshAttribute(profile)
	local equipped = {}
	for _, pet in profile.Data.Pets do
		if pet.Equipped then
			table.insert(equipped, pet)
		end
	end
	table.sort(equipped, function(a, b)
		return Formula.petPower(a.Id, a.Tier, a.Level) > Formula.petPower(b.Id, b.Tier, b.Level)
	end)
	local parts = {}
	for _, pet in equipped do
		local tier = Formula.tier(pet.Tier)
		table.insert(parts, if tier > 1 then pet.Id .. ":" .. tier else pet.Id)
	end
	profile.Player:SetAttribute("EquippedPets", table.concat(parts, ","))
end

local function equippedCount(data): number
	local count = 0
	for _, pet in data.Pets do
		if pet.Equipped then
			count += 1
		end
	end
	return count
end

-- Legendary-and-up pets are never removed by bulk tools, only one at a time on purpose.
local function isPrecious(pet): boolean
	return Config.Rarities[Pets[pet.Id].Rarity].Announce == true
end

function PetService.equipBest(profile)
	local data = profile.Data
	local slots = Formula.equipSlots(data, profile.Session)
	local ranked = {}
	for uid, pet in data.Pets do
		table.insert(ranked, { Uid = uid, Power = Formula.petPower(pet.Id, pet.Tier, pet.Level) })
	end
	table.sort(ranked, function(a, b)
		if a.Power == b.Power then
			return a.Uid < b.Uid
		end
		return a.Power > b.Power
	end)
	for rank, entry in ranked do
		data.Pets[entry.Uid].Equipped = rank <= slots
	end
	DataService.change(profile, "Pets")
	refreshAttribute(profile)
end

-- After the inventory changes: re-pick the best team if the player wants that, otherwise just
-- make sure the equipped pets on display are correct.
local function afterInventoryChange(profile)
	if profile.Data.Settings.AutoEquip then
		PetService.equipBest(profile)
	else
		DataService.change(profile, "Pets")
		refreshAttribute(profile)
	end
end

-- Adds a pet and returns its uid and whether it was a new index discovery.
function PetService.givePet(profile, petId: string, tier: number?, level: number?): (string, boolean)
	local data = profile.Data
	local uid = "p" .. data.NextPetUid
	data.NextPetUid += 1
	data.Pets[uid] = { Id = petId, Tier = Formula.tier(tier), Level = Formula.petLevel(level), Equipped = false }

	local discovered = false
	if not data.Index[petId] then
		data.Index[petId] = true
		discovered = true
		local rarity = Config.Rarities[Pets[petId].Rarity]
		DataService.addGems(profile, rarity.DiscoveryGems)
		DataService.change(profile, "Index")

		local egg = Eggs.ByPet[petId]
		if egg and Formula.eggIndexComplete(data, egg.Id) then
			DataService.notify(
				profile.Player,
				"🏅 "
					.. Zones.List[egg.Zone].Name
					.. " Pet Index complete! +"
					.. math.floor(Config.Bonuses.AreaIndexCoinBonus * 100 + 0.5)
					.. "% coins, forever.",
				"Reward"
			)
		end
	end
	DataService.change(profile, "Pets")
	return uid, discovered
end

-- Tells the server about Legendary-or-rarer pets and Emerald-or-better tiers.
local function announce(player: Player, result, odds: Formula.Odds, tierOdds: { number })
	local pet = Pets[result.Id]
	local rarity = Config.Rarities[pet.Rarity]
	if not rarity.Announce and result.Tier < ANNOUNCE_TIER then
		return
	end
	local chance = tierOdds[result.Tier]
	for _, entry in odds do
		if entry.Id == result.Id then
			chance *= entry.Chance
		end
	end
	local tier = Config.Tiers[result.Tier]
	local tierName = if result.Tier > 1 then tier.Icon .. " " .. tier.Name .. " " else ""
	announceRemote:FireAllClients(
		string.format(
			"%s hatched a %s%s %s (Lv %d)! (%s)",
			player.DisplayName,
			tierName,
			pet.Rarity,
			pet.Name,
			result.Level,
			Format.chance(chance)
		),
		if result.Tier >= ANNOUNCE_TIER then tier.Accent else rarity.Color
	)
end

local function hatch(profile, eggId, count)
	local player = profile.Player
	local data = profile.Data
	local session = profile.Session
	local egg = Eggs.ById[eggId]
	if not egg or (count ~= 1 and count ~= 3) then
		return
	end
	if count == 3 and not session.Passes.TripleHatch then
		local MonetizationService = require(script.Parent.MonetizationService) :: any
		MonetizationService.promptPass(profile, "TripleHatch")
		return
	end
	if egg.Zone > data.HighestZone then
		DataService.notify(player, "Unlock " .. Zones.List[egg.Zone].Name .. " first!", "Error")
		return
	end
	local now = os.clock()
	if now - (session.LastHatch or 0) < Config.Pets.HatchCooldown then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local eggPosition = WorldService.eggPosition(eggId)
	if not root or not eggPosition or (root.Position - eggPosition).Magnitude > Config.Pets.HatchRange then
		return
	end
	local cost = egg.Price * count
	if data.Coins < cost then
		DataService.notify(player, "You need 🪙 " .. Format.number(cost - data.Coins) .. " more!", "Error")
		return
	end

	-- Roll first so pets that will be auto-deleted don't need storage room. Each hatch rolls
	-- the pet, its tier and its level separately.
	local luck = Formula.luck(data, session)
	local odds = Formula.eggOdds(eggId, luck)
	local guaranteedOdds = nil :: Formula.Odds?
	local tierOdds = Formula.tierOdds(luck)
	local autoDelete = data.Settings.AutoDelete
	local results = {}
	local seen = {}
	local kept = 0
	-- Hatch pity: guarantee a Rare-or-better pet once misses reach Config.Hatch.PityMisses.
	local pity = data.HatchPity or 0
	local pityUsed = false
	for _ = 1, count do
		local guarantee = pity >= Config.Hatch.PityMisses
		local rolled = Formula.rollHatch(eggId, luck, rng, guarantee)
		local petId = rolled.Id
		if guarantee then
			pityUsed = true
			guaranteedOdds = guaranteedOdds or Formula.eggOdds(eggId, luck, true)
		end
		pity = if Config.Rarities[Pets[petId].Rarity].Lucky then 0 else pity + 1
		local isNew = not data.Index[petId] and not seen[petId]
		seen[petId] = true
		-- Auto-delete never takes new discoveries or pets that rolled a higher tier.
		local deleted = autoDelete[Pets[petId].Rarity] == true and not isNew and rolled.Tier == 1
		if not deleted then
			kept += 1
		end
		table.insert(results, {
			Id = petId,
			Tier = rolled.Tier,
			Level = rolled.Level,
			New = isNew,
			Deleted = deleted,
			Odds = if guarantee then guaranteedOdds else odds,
		})
	end
	if Formula.petCount(data) + kept > Config.Pets.Storage then
		DataService.notify(
			player,
			"Pet storage is full! Open 🐾 Pets → Delete Weak, or turn on auto-delete in ⚙️ Settings.",
			"Error"
		)
		return
	end

	session.LastHatch = now
	data.Coins -= cost
	data.HatchPity = pity
	for _, result in results do
		if not result.Deleted then
			result.Uid = PetService.givePet(profile, result.Id, result.Tier, result.Level)
		end
		announce(player, result, result.Odds, tierOdds)
		result.Odds = nil
	end
	data.Stats.EggsHatched += count
	AnalyticsService.sink(player, "Coins", data.Coins, cost, "Egg_" .. eggId)
	AnalyticsService.funnel(player, "FirstHatch")
	DataService.change(profile, "Coins", "Stats", "HatchPity")
	afterInventoryChange(profile)
	hatchedRemote:FireClient(player, eggId, results)
	if pityUsed then
		DataService.notify(player, "🍀 Pity guaranteed a Rare-or-better pet!", "Reward")
	end
end

local function setEquipped(profile, uid, equip)
	local data = profile.Data
	local pet = type(uid) == "string" and data.Pets[uid]
	if not pet then
		return
	end
	if equip == true and not pet.Equipped then
		if equippedCount(data) >= Formula.equipSlots(data, profile.Session) then
			DataService.notify(profile.Player, "All pet slots are full! Unequip one or get more slots.", "Error")
			return
		end
		pet.Equipped = true
	elseif equip == false then
		pet.Equipped = false
	end
	DataService.change(profile, "Pets")
	refreshAttribute(profile)
end

local function setLocked(profile, uids, locked)
	if type(uids) ~= "table" then
		return
	end
	local data = profile.Data
	for index, uid in uids do
		if index > MAX_BATCH then
			break
		end
		local pet = type(uid) == "string" and data.Pets[uid]
		if pet then
			pet.Locked = if locked == true then true else nil
		end
	end
	DataService.change(profile, "Pets")
end

-- Deletes the given pets, skipping locked and equipped ones.
local function deletePets(profile, uids)
	if type(uids) ~= "table" then
		return
	end
	local data = profile.Data
	local removed = 0
	for index, uid in uids do
		if index > MAX_BATCH then
			break
		end
		local pet = type(uid) == "string" and data.Pets[uid]
		if pet and not pet.Locked and not pet.Equipped then
			data.Pets[uid] = nil
			removed += 1
		end
	end
	if removed > 0 then
		DataService.change(profile, "Pets")
		DataService.notify(
			profile.Player,
			"🗑 Deleted " .. removed .. (if removed == 1 then " pet" else " pets"),
			"Info"
		)
	end
end

-- Deletes every unlocked, unequipped, Normal-tier pet weaker than your weakest equipped pet.
local function deleteWeak(profile)
	local data = profile.Data
	local weakest = math.huge
	for _, pet in data.Pets do
		if pet.Equipped then
			weakest = math.min(weakest, Formula.petPower(pet.Id, pet.Tier, pet.Level))
		end
	end
	if weakest == math.huge then
		DataService.notify(profile.Player, "Equip some pets first, then Delete Weak removes the weaker ones.", "Info")
		return
	end
	local removed = 0
	for uid, pet in data.Pets do
		local weak = Formula.petPower(pet.Id, pet.Tier, pet.Level) < weakest
		local upgraded = Formula.tier(pet.Tier) > 1
		if weak and not pet.Equipped and not pet.Locked and not upgraded and not isPrecious(pet) then
			data.Pets[uid] = nil
			removed += 1
		end
	end
	if removed == 0 then
		DataService.notify(profile.Player, "No weak pets to delete.", "Info")
		return
	end
	DataService.change(profile, "Pets")
	DataService.notify(profile.Player, "🗑 Deleted " .. removed .. " weak pets", "Success")
end

-- Combines CraftCopies unlocked copies of a pet at `tier` (any levels) into one pet of the next
-- tier. It uses unequipped and lower-level copies first, and the new pet keeps the highest level
-- among the copies used. Returns true on success.
local function craftTier(profile, petId: string, tier: number): boolean
	local data = profile.Data
	if tier >= #Config.Tiers then
		return false
	end
	local copies = {}
	for uid, pet in data.Pets do
		if pet.Id == petId and Formula.tier(pet.Tier) == tier and not pet.Locked then
			table.insert(copies, uid)
		end
	end
	if #copies < Config.Pets.CraftCopies then
		return false
	end
	table.sort(copies, function(a, b)
		local petA, petB = data.Pets[a], data.Pets[b]
		if petA.Equipped ~= petB.Equipped then
			return not petA.Equipped
		end
		local levelA, levelB = Formula.petLevel(petA.Level), Formula.petLevel(petB.Level)
		if levelA ~= levelB then
			return levelA < levelB
		end
		return a < b
	end)
	local level = 1
	for index = 1, Config.Pets.CraftCopies do
		local uid = copies[index]
		level = math.max(level, Formula.petLevel(data.Pets[uid].Level))
		data.Pets[uid] = nil
	end
	PetService.givePet(profile, petId, tier + 1, level)
	return true
end

local function craft(profile, petId, tier)
	if type(petId) ~= "string" or not Pets[petId] or type(tier) ~= "number" then
		return
	end
	tier = Formula.tier(tier)
	if tier >= #Config.Tiers then
		DataService.notify(profile.Player, "That pet is already the highest tier!", "Info")
		return
	end
	if not craftTier(profile, petId, tier) then
		DataService.notify(
			profile.Player,
			"You need " .. Config.Pets.CraftCopies .. " unlocked copies of the same pet and tier.",
			"Error"
		)
		return
	end
	afterInventoryChange(profile)
	local next = Config.Tiers[tier + 1]
	DataService.notify(
		profile.Player,
		next.Icon .. " Made a " .. next.Name .. " " .. Pets[petId].Name .. "!",
		"Success"
	)
end

-- Crafts everything possible, lowest tier first, so new pets can keep combining upwards.
local function craftAll(profile)
	local made = 0
	for tier = 1, #Config.Tiers - 1 do
		for petId in Pets do
			while craftTier(profile, petId, tier) do
				made += 1
			end
		end
	end
	if made == 0 then
		DataService.notify(
			profile.Player,
			"Nothing to craft yet: you need "
				.. Config.Pets.CraftCopies
				.. " unlocked copies of a pet at the same tier.",
			"Info"
		)
		return
	end
	afterInventoryChange(profile)
	DataService.notify(profile.Player, "✨ Crafted " .. made .. " upgraded pets!", "Success")
end

function PetService.Init()
	DataService.onLoaded(function(profile)
		local data = profile.Data
		-- Passes are resolved before this runs; trim if a pass was lost or slots changed.
		if equippedCount(data) > Formula.equipSlots(data, profile.Session) then
			PetService.equipBest(profile)
		else
			refreshAttribute(profile)
		end
	end)
end

function PetService.Start()
	for eggId, prompts in WorldService.EggPrompts do
		prompts.Single.Triggered:Connect(function(player)
			local profile = DataService.get(player)
			if profile then
				hatch(profile, eggId, 1)
			end
		end)
		prompts.Triple.Triggered:Connect(function(player)
			local profile = DataService.get(player)
			if profile then
				hatch(profile, eggId, 3)
			end
		end)
	end

	Actions.register("Hatch", function(profile, eggId, count)
		if type(eggId) == "string" and type(count) == "number" then
			hatch(profile, eggId, count)
		end
	end)
	Actions.register("Equip", function(profile, uid)
		setEquipped(profile, uid, true)
	end)
	Actions.register("Unequip", function(profile, uid)
		setEquipped(profile, uid, false)
	end)
	Actions.register("EquipBest", PetService.equipBest)
	Actions.register("SetLocked", setLocked)
	Actions.register("DeletePets", deletePets)
	Actions.register("DeleteWeak", deleteWeak)
	Actions.register("Craft", craft)
	Actions.register("CraftAll", craftAll)

	Players.PlayerRemoving:Connect(function(player)
		player:SetAttribute("EquippedPets", nil)
	end)
end

return PetService
