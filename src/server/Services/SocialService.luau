--[[
	Friend bonus: +10% coins for every friend in the server (capped), which makes inviting
	friends worth it and keeps groups playing together.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

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

function SocialService.Init()
	DataService.onLoaded(function()
		task.spawn(recompute)
	end)
end

function SocialService.Start()
	Players.PlayerRemoving:Connect(function(player)
		friendCache[player.UserId] = nil
		task.defer(recompute)
	end)
end

return SocialService
