--[[
	Tapping, upgrades, rebirths, area unlocks and characters.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Formula = require(Shared.Formula)
local Net = require(Shared.Net)
local Upgrades = require(Shared.Upgrades)
local Zones = require(Shared.Zones)

local Actions = require(script.Parent.Parent.Actions)
local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

local EconomyService = {}

local effectRemote = Net.event("Effect")

-- Token bucket per player so taps can't exceed Config.Tap.MaxPerSecond.
local buckets: { [Player]: { Tokens: number, Last: number } } = {}

local function takeTapToken(player: Player): boolean
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { Tokens = Config.Tap.MaxPerSecond, Last = now }
		buckets[player] = bucket
	end
	bucket.Tokens = math.min(Config.Tap.MaxPerSecond, bucket.Tokens + (now - bucket.Last) * Config.Tap.MaxPerSecond)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

local function tap(profile)
	DataService.addCoins(profile, Formula.tapValue(profile.Data, profile.Session), true)
	profile.Data.Stats.Taps += 1
	DataService.change(profile, "Stats")
end

function EconomyService.applyWalkSpeed(profile)
	local character = profile.Player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if humanoid then
		humanoid.WalkSpeed = Formula.walkSpeed(profile.Data)
	end
end

local function buyUpgrade(profile, upgradeId)
	if type(upgradeId) ~= "string" then
		return
	end
	local upgrade = Upgrades.ById[upgradeId]
	if not upgrade then
		return
	end
	local data = profile.Data
	local level = Formula.level(data, upgradeId)
	local cost = Formula.upgradeCost(upgradeId, level)
	if not cost then
		DataService.notify(profile.Player, upgrade.Name .. " is maxed out!", "Info")
		return
	end
	local balance = data[upgrade.Currency]
	if balance < cost then
		DataService.notify(profile.Player, "Not enough " .. string.lower(upgrade.Currency) .. "!", "Error")
		return
	end
	data[upgrade.Currency] -= cost
	data.Upgrades[upgradeId] = level + 1
	DataService.change(profile, upgrade.Currency, "Upgrades")

	if upgradeId == "WalkSpeed" then
		EconomyService.applyWalkSpeed(profile)
	elseif upgradeId == "PetSlots" then
		local PetService = require(script.Parent.PetService) :: any
		PetService.equipBest(profile)
	end
end

local function rebirth(profile)
	local data = profile.Data
	local cost = Formula.rebirthCost(data.Rebirths)
	if data.Coins < cost then
		DataService.notify(profile.Player, "You need 🪙 " .. Format.number(cost) .. " to rebirth.", "Error")
		return
	end
	local gems = Formula.rebirthGems(data.Rebirths)
	data.Coins = 0
	for _, upgrade in Upgrades.List do
		if upgrade.ResetsOnRebirth then
			data.Upgrades[upgrade.Id] = 0
		end
	end
	data.Rebirths += 1
	DataService.addGems(profile, gems)
	DataService.change(profile, "Coins", "Upgrades", "Rebirths")
	effectRemote:FireClient(profile.Player, "Rebirth", data.Rebirths, gems)
end

function EconomyService.unlockZone(profile, zoneIndex: number)
	local data = profile.Data
	local zone = Zones.List[zoneIndex]
	if not zone or zoneIndex ~= data.HighestZone + 1 then
		return
	end
	if data.Coins < zone.UnlockCost then
		DataService.notify(
			profile.Player,
			"You need 🪙 " .. Format.number(zone.UnlockCost - data.Coins) .. " more to unlock " .. zone.Name .. ".",
			"Error"
		)
		return
	end
	data.Coins -= zone.UnlockCost
	data.HighestZone = zoneIndex
	DataService.change(profile, "Coins", "HighestZone")
	effectRemote:FireClient(profile.Player, "ZoneUnlocked", zoneIndex)
end

local function setupCharacter(profile)
	local player = profile.Player
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.WalkSpeed = Formula.walkSpeed(profile.Data)
		humanoid.Died:Connect(function()
			task.wait(Players.RespawnTime)
			if player.Parent then
				player:LoadCharacter()
			end
		end)
	end)
	player:LoadCharacter()
end

function EconomyService.Init()
	DataService.onLoaded(setupCharacter)
	DataService.onRelease(function(profile)
		buckets[profile.Player] = nil
	end)
end

function EconomyService.Start()
	Net.event("Tap").OnServerEvent:Connect(function(player)
		local profile = DataService.get(player)
		if profile and takeTapToken(player) then
			tap(profile)
		end
	end)

	Actions.register("BuyUpgrade", buyUpgrade)
	Actions.register("Rebirth", rebirth)
	Actions.register("UnlockZone", function(profile, zoneIndex)
		if type(zoneIndex) == "number" then
			EconomyService.unlockZone(profile, zoneIndex)
		end
	end)
	Actions.register("SetAutoTap", function(profile, enabled)
		if not profile.Session.Passes.AutoTap then
			return
		end
		profile.Session.AutoTap = enabled == true
		DataService.change(profile, "Session.AutoTap")
	end)

	for zoneIndex, prompts in WorldService.Gates do
		for _, prompt in prompts do
			prompt.Triggered:Connect(function(player)
				local profile = DataService.get(player)
				if profile then
					EconomyService.unlockZone(profile, zoneIndex)
				end
			end)
		end
	end

	-- Auto Tapper pass
	task.spawn(function()
		local interval = 1 / Config.Tap.AutoPerSecond
		while true do
			task.wait(interval)
			for _, profile in DataService.all() do
				if profile.Session.AutoTap and profile.Session.Passes.AutoTap then
					tap(profile)
				end
			end
		end
	end)
end

return EconomyService
