--[[
	🛠 Admin panel commands for testing and debugging. Every command re-checks that the caller
	is an admin on the server, so the panel can't be abused even if someone fakes the client.
	Admins: everyone in Studio, the place owner (or group rank Config.Admins.GroupMinRank+),
	and anyone listed in Config.Admins.UserIds.
]]

local GroupService = game:GetService("GroupService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Eggs = require(Shared.Eggs)
local Format = require(Shared.Format)
local Formula = require(Shared.Formula)
local Net = require(Shared.Net)
local Pets = require(Shared.Pets)
local Products = require(Shared.Products)
local Upgrades = require(Shared.Upgrades)
local Zones = require(Shared.Zones)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local MonetizationService = require(script.Parent.MonetizationService)
local PetService = require(script.Parent.PetService)
local RewardService = require(script.Parent.RewardService)

local AdminService = {}

local MAX_AMOUNT = 1e30
local startedAt = os.clock()

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() or table.find(Config.Admins.UserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
		if ok then
			for _, group in groups do
				if group.Id == game.CreatorId then
					return group.Rank >= Config.Admins.GroupMinRank
				end
			end
		end
	end
	return false
end

local function amount(value: any): number?
	local number = tonumber(value)
	if not number or number ~= number then
		return nil
	end
	return math.clamp(number, -MAX_AMOUNT, MAX_AMOUNT)
end

type Command = (profile: any, ...any) -> (boolean, string)

local COMMANDS: { [string]: Command } = {}

-- Currency ------------------------------------------------------------------------------------

COMMANDS.AddCoins = function(profile, value)
	local add = amount(value)
	if not add then
		return false, "Enter a number."
	end
	profile.Data.Coins = math.max(0, profile.Data.Coins + add)
	DataService.change(profile, "Coins")
	return true, "Coins: " .. Format.number(profile.Data.Coins)
end

COMMANDS.AddGems = function(profile, value)
	local add = amount(value)
	if not add then
		return false, "Enter a number."
	end
	profile.Data.Gems = math.max(0, math.floor(profile.Data.Gems + add))
	DataService.change(profile, "Gems")
	return true, "Gems: " .. Format.number(profile.Data.Gems)
end

COMMANDS.ResetCurrency = function(profile)
	profile.Data.Coins = 0
	profile.Data.Gems = 0
	DataService.change(profile, "Coins", "Gems")
	return true, "Coins and gems set to 0."
end

-- Pets ----------------------------------------------------------------------------------------

COMMANDS.GivePet = function(profile, petId, tier, count)
	if type(petId) ~= "string" or not Pets[petId] then
		return false, "Unknown pet."
	end
	local copies = math.clamp(math.floor(tonumber(count) or 1), 1, 50)
	local petTier = Formula.tier(tier)
	for _ = 1, copies do
		PetService.givePet(profile, petId, petTier)
	end
	PetService.equipBest(profile)
	return true, string.format("Gave %d× %s %s.", copies, Config.Tiers[petTier].Name, Pets[petId].Name)
end

COMMANDS.GiveEveryPet = function(profile)
	local given = 0
	for petId in Pets do
		PetService.givePet(profile, petId, 1)
		given += 1
	end
	PetService.equipBest(profile)
	return true, "Gave one of each of the " .. given .. " pets (index complete)."
end

COMMANDS.ClearPets = function(profile)
	table.clear(profile.Data.Pets)
	PetService.equipBest(profile)
	return true, "All pets removed (index kept)."
end

-- Luck & boosts -------------------------------------------------------------------------------

COMMANDS.SetLuckLevel = function(profile, level)
	local target = math.clamp(math.floor(tonumber(level) or 0), 0, Config.Luck.MaxLevel)
	profile.Data.LuckXP = if target == 0 then 0 else Formula.luckXPForLevel(target)
	DataService.change(profile, "LuckXP")
	return true,
		"Luck level " .. target .. " (luck " .. Format.multiplier(Formula.luck(profile.Data, profile.Session)) .. ")"
end

COMMANDS.AddLuckLevels = function(profile, levels)
	local current = Formula.luckLevel(profile.Data.LuckXP)
	return COMMANDS.SetLuckLevel(profile, current + (tonumber(levels) or 0))
end

COMMANDS.AddBoost = function(profile, kind, minutes)
	if kind ~= "Coins" and kind ~= "Luck" then
		return false, "Unknown boost."
	end
	DataService.addBoost(profile, kind, math.clamp(tonumber(minutes) or 15, 1, 1440) * 60)
	return true, "2x " .. kind .. " for " .. Format.time(profile.Data.Boosts[kind]) .. "."
end

COMMANDS.ClearBoosts = function(profile)
	profile.Data.Boosts.Coins = 0
	profile.Data.Boosts.Luck = 0
	DataService.change(profile, "Boosts")
	return true, "Boosts cleared."
end

-- Progress ------------------------------------------------------------------------------------

COMMANDS.SetHighestZone = function(profile, index)
	local zone = math.clamp(math.floor(tonumber(index) or 1), 1, #Zones.List)
	profile.Data.HighestZone = zone
	DataService.change(profile, "HighestZone")
	return true, "Unlocked up to " .. Zones.List[zone].Name .. "."
end

COMMANDS.AddRebirths = function(profile, count)
	profile.Data.Rebirths = math.max(0, profile.Data.Rebirths + math.floor(tonumber(count) or 1))
	DataService.change(profile, "Rebirths")
	return true, "Rebirths: " .. profile.Data.Rebirths
end

COMMANDS.MaxUpgrades = function(profile)
	for _, upgrade in Upgrades.List do
		profile.Data.Upgrades[upgrade.Id] = upgrade.MaxLevel
	end
	DataService.change(profile, "Upgrades")
	EconomyService.applyWalkSpeed(profile)
	PetService.equipBest(profile)
	return true, "Every upgrade maxed."
end

COMMANDS.ResetUpgrades = function(profile)
	for _, upgrade in Upgrades.List do
		profile.Data.Upgrades[upgrade.Id] = 0
	end
	DataService.change(profile, "Upgrades")
	EconomyService.applyWalkSpeed(profile)
	PetService.equipBest(profile)
	return true, "Upgrades reset."
end

-- Timers --------------------------------------------------------------------------------------

COMMANDS.DailyReady = function(profile)
	-- Just past the cooldown, so the streak continues.
	profile.Data.Daily.Last = os.time() - Config.Daily.CooldownHours * 3600 - 1
	DataService.change(profile, "Daily")
	return true, "Daily reward is ready."
end

COMMANDS.GiftsReady = function(profile)
	local longest = 0
	for _, gift in Config.Gifts do
		longest = math.max(longest, gift.Minutes)
	end
	profile.Session.JoinedAt = workspace:GetServerTimeNow() - longest * 60 - 1
	DataService.change(profile, "Session.JoinedAt")
	return true, "Every gift is ready."
end

COMMANDS.CompleteQuests = function(profile)
	local data = profile.Data
	for _, quest in data.Quests do
		quest.Start = (data.Stats[quest.Stat] or 0) - quest.Goal
	end
	DataService.change(profile, "Quests")
	return true, "Quests are ready to claim."
end

-- Passes --------------------------------------------------------------------------------------

COMMANDS.SetPass = function(profile, key, owned)
	if type(key) ~= "string" or not Products.PassByKey[key] then
		return false, "Unknown pass."
	end
	MonetizationService.setPass(profile, key, owned == true)
	return true, Products.PassByKey[key].Name .. (if owned then " on" else " off") .. " (this session only)."
end

-- Testing -------------------------------------------------------------------------------------

COMMANDS.SimulateHatches = function(profile, eggId, count)
	local egg = type(eggId) == "string" and Eggs.ById[eggId]
	if not egg then
		return false, "Unknown egg."
	end
	local rolls = math.clamp(math.floor(tonumber(count) or 10000), 1, 200000)
	local luck = Formula.luck(profile.Data, profile.Session)
	local odds = Formula.eggOdds(egg.Id, luck)
	local rng = Random.new()
	local counts = table.create(#odds, 0)
	for _ = 1, rolls do
		local roll = rng:NextNumber()
		local picked = #odds
		for index, entry in odds do
			roll -= entry.Chance
			if roll <= 0 then
				picked = index
				break
			end
		end
		counts[picked] += 1
	end
	local lines = {
		string.format("%s × %s at luck %s (no coins spent):", Format.commas(rolls), egg.Name, Format.multiplier(luck)),
	}
	for index, entry in odds do
		table.insert(
			lines,
			string.format(
				"%s: %s (%s, expected %s)",
				Pets[entry.Id].Name,
				Format.commas(counts[index]),
				Format.chance(counts[index] / rolls),
				Format.chance(entry.Chance)
			)
		)
	end
	return true, table.concat(lines, "\n")
end

COMMANDS.Teleport = function(profile, index)
	local zone = math.clamp(math.floor(tonumber(index) or 1), 1, #Zones.List)
	local character = profile.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false, "No character."
	end
	local zoneStart = (zone - 1) * Zones.Layout.Length
	root.CFrame = CFrame.new(0, 5, zoneStart + 30) * CFrame.Angles(0, math.pi, 0)
	return true, "Teleported to " .. Zones.List[zone].Name .. "."
end

COMMANDS.ServerInfo = function(profile)
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, profile.Data)
	local lines = {
		"Players: " .. #Players:GetPlayers() .. "   Uptime: " .. Format.time(os.clock() - startedAt),
		"Place version: " .. game.PlaceVersion .. "   Studio: " .. tostring(RunService:IsStudio()),
		"DataStore: " .. (if DataService.isMock() then "in-memory (Studio, not saving)" else "live, saving"),
		"Your save size: " .. (if ok then Format.commas(#encoded) .. " bytes (limit 4,194,304)" else "?"),
		"Server memory: " .. math.floor(Stats:GetTotalMemoryUsageMb()) .. " MB",
		"Pets owned: "
			.. Formula.petCount(profile.Data)
			.. "/"
			.. Config.Pets.Storage
			.. "   Luck: "
			.. Format.multiplier(Formula.luck(profile.Data, profile.Session)),
	}
	return true, table.concat(lines, "\n")
end

COMMANDS.SaveNow = function(profile)
	local saved = DataService.save(profile)
	return saved, if saved then "Saved." else "Save failed (see Output)."
end

COMMANDS.ResetData = function(profile)
	DataService.reset(profile)
	RewardService.fillQuests(profile)
	PetService.equipBest(profile)
	EconomyService.applyWalkSpeed(profile)
	return true, "Your data was reset to a brand new player (purchases kept)."
end

local function run(player: Player, name: any, ...: any): (boolean, string)
	local profile = DataService.get(player)
	if not profile or not profile.Session.IsAdmin then
		return false, "Not allowed."
	end
	local command = type(name) == "string" and COMMANDS[name]
	if not command then
		return false, "Unknown command."
	end
	local ok, success, message = pcall(command, profile, ...)
	if not ok then
		warn("[Admin] " .. tostring(name) .. " failed: " .. tostring(success))
		return false, "Error: " .. tostring(success)
	end
	print(string.format("[Admin] %s ran %s", player.Name, name))
	return success, message
end

function AdminService.Init()
	DataService.onLoaded(function(profile)
		profile.Session.IsAdmin = isAdmin(profile.Player)
		DataService.change(profile, "Session.IsAdmin")
	end)
end

function AdminService.Start()
	Net.func("AdminCommand").OnServerInvoke = run
end

return AdminService
