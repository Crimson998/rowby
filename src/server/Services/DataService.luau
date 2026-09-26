--[[
	Loads, replicates and saves player profiles.

	- Session locking: a profile records which server owns it, so two servers can never both
	  write the same player (which is how item duplication exploits usually happen).
	- Replication: services mark keys dirty with DataService.change(); dirty keys are flushed
	  to the owning client ten times a second as a partial Sync.
	- Studio without API access falls back to in-memory data so the game is still playable.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formula = require(Shared.Formula)
local Net = require(Shared.Net)

local DataService = {}

export type Profile = {
	Player: Player,
	Data: any,
	Session: any,
	Dirty: { Data: { [string]: boolean }, Session: { [string]: boolean } },
	Saving: boolean,
	Released: boolean,
}

local DATA_VERSION = 2

local TEMPLATE = {
	Version = DATA_VERSION,
	Coins = 0,
	Gems = 0,
	Rebirths = 0,
	HighestZone = 1,
	-- Lifetime Luck XP from clovers; sets the Luck level.
	LuckXP = 0,
	Upgrades = {
		TapPower = 0,
		Magnet = 0,
		WalkSpeed = 0,
		PetSlots = 0,
		Luck = 0,
		CoinMastery = 0,
	},
	-- [uid] = { Id = petId, Tier = 1..#Config.Tiers, Equipped = bool, Locked = true? }
	Pets = {},
	NextPetUid = 1,
	-- [petId] = true once discovered
	Index = {},
	-- Seconds remaining; boosts only tick down while you're playing.
	Boosts = { Coins = 0, Luck = 0 },
	Daily = { Last = 0, Streak = 0 },
	Quests = {},
	QuestsCompleted = 0,
	Stats = {
		Taps = 0,
		CoinsEarned = 0,
		EggsHatched = 0,
		OrbsCollected = 0,
		TimePlayed = 0,
		RobuxSpent = 0,
	},
	-- [CODE] = true
	Codes = {},
	-- [productKey] = true for one-time products (Starter Pack)
	OneTime = {},
	-- Most recent receipt ids, so a retried receipt is never granted twice.
	Purchases = {},
	-- Player preferences, changed from the ⚙️ Settings window.
	Settings = {
		-- "Full", "Fast" or "Off"
		HatchAnimation = "Full",
		-- Equip your strongest pets automatically after hatching or crafting.
		AutoEquip = true,
		Sounds = true,
		ShowOtherPets = true,
		-- Hatched pets of these rarities are deleted right away (new discoveries are always kept).
		AutoDelete = { Common = false, Uncommon = false, Rare = false, Epic = false },
	},
}

local profiles: { [Player]: Profile } = {}
local loadedHandlers: { (Profile) -> () } = {}
local releaseHandlers: { (Profile) -> () } = {}

local syncRemote = Net.event("Sync")
local notifyRemote = Net.event("Notify")

local store: DataStore? = nil
local mockMode = false

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = deepCopy(inner)
	end
	return copy
end

-- Adds keys that exist in the template but not in saved data (new features after release).
local function reconcile(target, template)
	for key, value in template do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil then
			reconcile(target[key], value)
		end
	end
end

local function migrate(data)
	-- Bump DATA_VERSION and transform old data here when the save format changes.
	if (data.Version or 1) < 2 then
		-- v2: Golden = true/false became Tier (1 = Normal, 2 = Golden, 3+ = higher tiers).
		for _, pet in data.Pets do
			pet.Tier = if pet.Golden then 2 else 1
			pet.Golden = nil
		end
	end
	data.Version = DATA_VERSION
end

local function keyFor(userId: number): string
	return "Player_" .. userId
end

local function isStudioAccessError(message: string): boolean
	return RunService:IsStudio()
		and (
			string.find(message, "403") ~= nil
			or string.find(message, "Studio") ~= nil
			or string.find(message, "API") ~= nil
		)
end

local function enableMock(reason: string)
	if not mockMode then
		mockMode = true
		warn("[DataService] Using temporary in-memory data (" .. reason .. ").")
		warn(
			"[DataService] Enable Game Settings → Security → 'Enable Studio Access to API Services' to test saving."
		)
	end
end

local function newSession(player: Player)
	return {
		Passes = {},
		Premium = player.MembershipType == Enum.MembershipType.Premium,
		FriendBonus = 0,
		RandomItemsRestricted = false,
		JoinedAt = workspace:GetServerTimeNow(),
		GiftsClaimed = table.create(#Config.Gifts, false),
		AutoTap = false,
		IsStudio = RunService:IsStudio(),
	}
end

local function loadData(player: Player): any?
	if mockMode or not store then
		return deepCopy(TEMPLATE)
	end
	local dataStore = store :: DataStore
	local key = keyFor(player.UserId)
	local maxAttempts = 6
	for attempt = 1, maxAttempts do
		local lockedElsewhere = false
		local ok, result = pcall(function()
			return dataStore:UpdateAsync(key, function(old)
				lockedElsewhere = false
				local data = old or deepCopy(TEMPLATE)
				local lock = data._Lock
				local lockIsFresh = lock
					and lock.JobId ~= game.JobId
					and os.time() - lock.Time < Config.Data.SessionLockSeconds
				-- On the final attempt take the lock anyway; the other server's saves will then be rejected.
				if lockIsFresh and attempt < maxAttempts then
					lockedElsewhere = true
					return nil
				end
				data._Lock = { JobId = game.JobId, Time = os.time() }
				return data, { player.UserId }
			end)
		end)
		if ok and not lockedElsewhere then
			return result
		end
		if not ok then
			local message = tostring(result)
			if isStudioAccessError(message) then
				enableMock(message)
				return deepCopy(TEMPLATE)
			end
			warn(string.format("[DataService] Load attempt %d for %s failed: %s", attempt, player.Name, message))
		end
		if not player.Parent then
			return nil
		end
		task.wait(if lockedElsewhere then 5 else 2 ^ attempt)
	end
	return nil
end

-- Returns true when the data is safely stored (or when running on mock data).
local function writeData(profile: Profile, release: boolean): boolean
	if mockMode or not store then
		return true
	end
	local dataStore = store :: DataStore
	local player = profile.Player
	local snapshot = deepCopy(profile.Data)
	local stolen = false
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			dataStore:UpdateAsync(keyFor(player.UserId), function(old)
				stolen = false
				if old and old._Lock and old._Lock.JobId ~= game.JobId then
					stolen = true
					return nil
				end
				snapshot._Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
				return snapshot, { player.UserId }
			end)
		end)
		if ok then
			if stolen then
				warn("[DataService] " .. player.Name .. "'s session was taken by another server; not saving.")
				if player.Parent then
					player:Kick("Your progress was loaded in another server. Please rejoin.")
				end
				return false
			end
			return true
		end
		warn(string.format("[DataService] Save attempt %d for %s failed: %s", attempt, player.Name, tostring(err)))
		task.wait(2 ^ attempt)
	end
	return false
end

-- Saves one profile, serialising overlapping saves for the same player. Returns false once the
-- session has been released, so a purchase granted after the final save is retried on rejoin.
function DataService.save(profile: Profile, release: boolean?): boolean
	while profile.Saving do
		task.wait()
	end
	if profile.Released then
		return false
	end
	profile.Saving = true
	local ok = writeData(profile, release == true)
	if release then
		profile.Released = true
	end
	profile.Saving = false
	return ok
end

function DataService.get(player: Player): Profile?
	return profiles[player]
end

function DataService.waitFor(player: Player, timeout: number?): Profile?
	local deadline = os.clock() + (timeout or 15)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.all(): { [Player]: Profile }
	return profiles
end

-- Snapshot of loaded profiles, safe to iterate across yields.
function DataService.list(): { Profile }
	local list = {}
	for _, profile in profiles do
		table.insert(list, profile)
	end
	return list
end

function DataService.isMock(): boolean
	return mockMode
end

-- Handlers run in registration order and may yield, so earlier services can finish setting
-- session state (e.g. game passes) before later ones read it.
function DataService.onLoaded(handler: (Profile) -> ())
	table.insert(loadedHandlers, handler)
end

function DataService.onRelease(handler: (Profile) -> ())
	table.insert(releaseHandlers, handler)
end

-- Marks keys for replication: DataService.change(profile, "Coins", "Stats") or
-- DataService.change(profile, "Session.Passes").
-- Sends the whole profile again (after large changes such as an admin data reset).
function DataService.resync(profile: Profile)
	table.clear(profile.Dirty.Data)
	table.clear(profile.Dirty.Session)
	syncRemote:FireClient(profile.Player, { Data = profile.Data, Session = profile.Session, Full = true })
end

-- Admin/testing: wipes the profile back to a new player's data. Receipts and one-time
-- purchases are kept so real purchases can never be granted twice.
function DataService.reset(profile: Profile)
	local old = profile.Data
	local fresh = deepCopy(TEMPLATE)
	fresh.Purchases = old.Purchases
	fresh.OneTime = old.OneTime
	profile.Data = fresh
	DataService.resync(profile)
end

function DataService.change(profile: Profile, ...: string)
	for _, key in { ... } do
		local section, name = string.match(key, "^(%a+)%.(.+)$")
		if section == "Session" and name then
			profile.Dirty.Session[name] = true
		else
			profile.Dirty.Data[key] = true
		end
	end
end

function DataService.notify(player: Player, text: string, kind: string?)
	notifyRemote:FireClient(player, text, kind or "Info")
end

function DataService.addCoins(profile: Profile, amount: number, earned: boolean)
	if amount ~= amount or amount <= 0 then
		return
	end
	local data = profile.Data
	data.Coins += amount
	if earned then
		data.Stats.CoinsEarned += amount
		DataService.change(profile, "Stats")
	end
	DataService.change(profile, "Coins")
end

function DataService.addGems(profile: Profile, amount: number)
	if amount <= 0 then
		return
	end
	profile.Data.Gems += math.floor(amount)
	DataService.change(profile, "Gems")
end

function DataService.addBoost(profile: Profile, kind: string, seconds: number)
	local boosts = profile.Data.Boosts
	boosts[kind] = (boosts[kind] or 0) + seconds
	DataService.change(profile, "Boosts")
end

-- Grants a reward table (see Config.Daily). Pets are granted by PetService.
function DataService.grantReward(profile: Profile, reward)
	if reward.Gems then
		DataService.addGems(profile, reward.Gems)
	end
	if reward.CoinSeconds then
		DataService.addCoins(profile, Formula.rewardCoins(profile.Data, profile.Session, reward.CoinSeconds), false)
	end
	if reward.CoinBoostMinutes then
		DataService.addBoost(profile, "Coins", reward.CoinBoostMinutes * 60)
	end
	if reward.LuckBoostMinutes then
		DataService.addBoost(profile, "Luck", reward.LuckBoostMinutes * 60)
	end
end

local function flush()
	for player, profile in profiles do
		local dirty = profile.Dirty
		if next(dirty.Data) == nil and next(dirty.Session) == nil then
			continue
		end
		local payload = { Data = {}, Session = {} }
		for key in dirty.Data do
			payload.Data[key] = profile.Data[key]
		end
		for key in dirty.Session do
			payload.Session[key] = profile.Session[key]
		end
		table.clear(dirty.Data)
		table.clear(dirty.Session)
		syncRemote:FireClient(player, payload)
	end
end

local function onPlayerAdded(player: Player)
	local data = loadData(player)
	if not player.Parent then
		if data and not mockMode then
			-- Left while loading: release the lock we just took.
			local ghost = {
				Player = player,
				Data = data,
				Session = {},
				Dirty = { Data = {}, Session = {} },
				Saving = false,
				Released = false,
			}
			data._Lock = nil
			DataService.save(ghost :: any, true)
		end
		return
	end
	if not data then
		player:Kick("We couldn't load your data right now. Please rejoin in a minute!")
		return
	end

	data._Lock = nil
	reconcile(data, TEMPLATE)
	migrate(data)

	local profile: Profile = {
		Player = player,
		Data = data,
		Session = newSession(player),
		Dirty = { Data = {}, Session = {} },
		Saving = false,
		Released = false,
	}
	profiles[player] = profile
	syncRemote:FireClient(player, { Data = data, Session = profile.Session, Full = true })

	for _, handler in loadedHandlers do
		local ok, err = pcall(handler, profile)
		if not ok then
			warn("[DataService] onLoaded handler failed: " .. tostring(err))
		end
		if not player.Parent then
			return
		end
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	for _, handler in releaseHandlers do
		local ok, err = pcall(handler, profile)
		if not ok then
			warn("[DataService] onRelease handler failed: " .. tostring(err))
		end
	end
	DataService.save(profile, true)
	profiles[player] = nil
end

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok then
		store = result
	else
		enableMock(tostring(result))
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.1 then
			elapsed = 0
			flush()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveSeconds)
			for _, profile in DataService.list() do
				task.spawn(DataService.save, profile)
				task.wait(0.25)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, profile in DataService.list() do
			pending += 1
			task.spawn(function()
				onPlayerRemoving(profile.Player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
