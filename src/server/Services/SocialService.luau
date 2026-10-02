--!strict
--[[
	Friend bonus: +10% coins for every friend in the server (capped), which makes inviting
	friends worth it and keeps groups playing together.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Pets = require(Shared.Pets)

local DataService = require(script.Parent.DataService)

local SocialService = {}

-- friendCache[a][b] = are a and b friends
local friendCache: { [number]: { [number]: boolean } } = {}

local function areFriends(a: Player, b: Player): boolean
	friendCache[a.UserId] = friendCache[a.UserId] or {}
	local cached = friendCache[a.UserId][b.UserId]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(a.IsFriendsWithAsync, a, b.UserId)
	local friends = ok and result == true
	friendCache[a.UserId][b.UserId] = friends
	friendCache[b.UserId] = friendCache[b.UserId] or {}
	friendCache[b.UserId][a.UserId] = friends
	return friends
end

local function recompute()
	for _, profile in DataService.list() do
		local player = profile.Player
		if not player.Parent then
			continue
		end
		local count = 0
		for _, other in Players:GetPlayers() do
			if other ~= player and areFriends(player, other) then
				count += 1
			end
		end
		local bonus = math.min(count * Config.Bonuses.FriendBonusPerFriend, Config.Bonuses.MaxFriendBonus)
		if bonus ~= profile.Session.FriendBonus then
			if bonus > profile.Session.FriendBonus then
				DataService.notify(
					player,
					"👋 Friend bonus: +" .. math.floor(bonus * 100 + 0.5) .. "% coins!",
					"Success"
				)
			end
			profile.Session.FriendBonus = bonus
			DataService.change(profile, "Session.FriendBonus")
		end
	end
end

local MAX_TEAM = 12
local lastInspect: { [Player]: number } = {}

-- Public summary of another player in the server: their equipped team and progress.
local function inspect(caller: Player, userId): { [string]: any }?
	if type(userId) ~= "number" then
		return nil
	end
	local now = os.clock()
	if now - (lastInspect[caller] or 0) < 0.5 then
		return nil
	end
	lastInspect[caller] = now
	local target = Players:GetPlayerByUserId(userId)
	local profile = target and DataService.get(target)
	if not target or not profile then
		return nil
	end
	local data = profile.Data
	local team = {}
	for _, pet in data.Pets do
		if pet.Equipped and Pets[pet.Id] then
			table.insert(team, { Id = pet.Id, Tier = pet.Tier, Level = pet.Level })
		end
	end
	table.sort(team, function(a, b)
		return a.Level * a.Tier > b.Level * b.Tier
	end)
	while #team > MAX_TEAM do
		table.remove(team)
	end
	local discovered, total = 0, 0
	for petId in Pets do
		total += 1
		if data.Index[petId] then
			discovered += 1
		end
	end
	return {
		Name = target.DisplayName,
		Rebirths = data.Rebirths,
		HighestZone = data.HighestZone,
		EggsHatched = data.Stats.EggsHatched,
		Discovered = discovered,
		TotalPets = total,
		Team = team,
	}
end

function SocialService.Init()
	DataService.onLoaded(function()
		task.spawn(recompute)
	end)
end

function SocialService.Start()
	Net.func("InspectPlayer").OnServerInvoke = inspect
	Players.PlayerRemoving:Connect(function(player)
		friendCache[player.UserId] = nil
		lastInspect[player] = nil
		task.defer(recompute)
	end)
end

return SocialService
