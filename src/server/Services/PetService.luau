--[[
	Hatching, inventory, equipping, golden crafting and the pet index.
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
local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

local PetService = {}

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
		return Formula.petPower(a.Id, a.Golden) > Formula.petPower(b.Id, b.Golden)
	end)
	local parts = {}
	for _, pet in equipped do
		table.insert(parts, if pet.Golden then pet.Id .. ":G" else pet.Id)
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

function PetService.equipBest(profile)
	local data = profile.Data
	local slots = Formula.equipSlots(data, profile.Session)
	local ranked = {}
	for uid, pet in data.Pets do
		table.insert(ranked, { Uid = uid, Power = Formula.petPower(pet.Id, pet.Golden) })
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

-- Adds a pet and returns its uid and whether it was a new index discovery.
function PetService.givePet(profile, petId: string, golden: boolean?): (string, boolean)
	local data = profile.Data
	local uid = "p" .. data.NextPetUid
	data.NextPetUid += 1
	data.Pets[uid] = { Id = petId, Golden = golden == true, Equipped = false }

	local discovered = false
	if not data.Index[petId] then
		data.Index[petId] = true
		discovered = true
		local rarity = Config.Rarities[Pets[petId].Rarity]
		DataService.addGems(profile, rarity.DiscoveryGems)
		DataService.change(profile, "Index")
	end
	DataService.change(profile, "Pets")
	return uid, discovered
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
	if Formula.petCount(data) + count > Config.Pets.Storage then
		DataService.notify(player, "Pet storage is full! Delete or combine some pets.", "Error")
		return
	end
	local cost = egg.Price * count
	if data.Coins < cost then
		DataService.notify(player, "You need 🪙 " .. Format.number(cost - data.Coins) .. " more!", "Error")
		return
	end

	session.LastHatch = now
	data.Coins -= cost
	local luck = Formula.luck(data, session)
	local odds = Formula.eggOdds(eggId, luck)
	local results = {}
	for _ = 1, count do
		local petId = Formula.rollEgg(eggId, luck, rng)
		local uid, discovered = PetService.givePet(profile, petId, false)
		table.insert(results, { Id = petId, Uid = uid, New = discovered })

		local pet = Pets[petId]
		if Config.Rarities[pet.Rarity].Announce then
			local chance = 0
			for _, entry in odds do
				if entry.Id == petId then
					chance = entry.Chance
				end
			end
			announceRemote:FireAllClients(
				string.format(
					"%s hatched a %s %s! (%s)",
					player.DisplayName,
					pet.Rarity,
					pet.Name,
					Format.chance(chance)
				),
				Config.Rarities[pet.Rarity].Color
			)
		end
	end
	data.Stats.EggsHatched += count
	DataService.change(profile, "Coins", "Stats")
	PetService.equipBest(profile)
	hatchedRemote:FireClient(player, eggId, results)
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

local function deletePets(profile, uids)
	if type(uids) ~= "table" then
		return
	end
	local data = profile.Data
	local removed = 0
	for index, uid in uids do
		if index > 100 then
			break
		end
		if type(uid) == "string" and data.Pets[uid] then
			data.Pets[uid] = nil
			removed += 1
		end
	end
	if removed > 0 then
		DataService.change(profile, "Pets")
		refreshAttribute(profile)
	end
end

local function makeGolden(profile, petId)
	local data = profile.Data
	if type(petId) ~= "string" or not Pets[petId] then
		return
	end
	local copies = {}
	for uid, pet in data.Pets do
		if pet.Id == petId and not pet.Golden then
			table.insert(copies, uid)
		end
	end
	if #copies < Config.Pets.GoldenCopies then
		DataService.notify(
			profile.Player,
			"You need " .. Config.Pets.GoldenCopies .. " of the same pet to make it golden.",
			"Error"
		)
		return
	end
	-- Use unequipped copies first.
	table.sort(copies, function(a, b)
		local aEquipped, bEquipped = data.Pets[a].Equipped, data.Pets[b].Equipped
		if aEquipped ~= bEquipped then
			return not aEquipped
		end
		return a < b
	end)
	for index = 1, Config.Pets.GoldenCopies do
		data.Pets[copies[index]] = nil
	end
	PetService.givePet(profile, petId, true)
	PetService.equipBest(profile)
	DataService.notify(profile.Player, "✨ Made a Golden " .. Pets[petId].Name .. "!", "Success")
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
	Actions.register("DeletePets", deletePets)
	Actions.register("MakeGolden", makeGolden)

	Players.PlayerRemoving:Connect(function(player)
		player:SetAttribute("EquippedPets", nil)
	end)
end

return PetService
