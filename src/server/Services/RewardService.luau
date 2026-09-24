--[[
	Free rewards that bring players back: daily streak, playtime gifts, quests and codes.
	Also ticks boost timers and time played.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formula = require(Shared.Formula)
local Net = require(Shared.Net)
local Quests = require(Shared.Quests)
local Rewards = require(Shared.Rewards)

local Actions = require(script.Parent.Parent.Actions)
local DataService = require(script.Parent.DataService)

local RewardService = {}

local rng = Random.new()
local lastCodeAttempt: { [Player]: number } = {}

local function newQuest(profile, exclude: { [string]: boolean })
	local candidates = {}
	for _, template in Quests.Templates do
		if not exclude[template.Stat] then
			table.insert(candidates, template)
		end
	end
	local template = candidates[rng:NextInteger(1, #candidates)]
	local data = profile.Data
	return {
		Stat = template.Stat,
		Goal = template.Goal(data, profile.Session),
		Start = data.Stats[template.Stat] or 0,
		Gems = template.Gems,
	}
end

local function fillQuests(profile)
	local quests = profile.Data.Quests
	local used = {}
	for _, quest in quests do
		used[quest.Stat] = true
	end
	while #quests < Quests.Slots do
		local quest = newQuest(profile, used)
		used[quest.Stat] = true
		table.insert(quests, quest)
	end
	DataService.change(profile, "Quests")
end

local function claimQuest(profile, slot)
	local data = profile.Data
	local quest = type(slot) == "number" and data.Quests[slot]
	if not quest or Quests.progress(data, quest) < quest.Goal then
		return
	end
	DataService.addGems(profile, quest.Gems)
	data.QuestsCompleted += 1
	local used = {}
	for index, other in data.Quests do
		if index ~= slot then
			used[other.Stat] = true
		end
	end
	used[quest.Stat] = true
	data.Quests[slot] = newQuest(profile, used)
	DataService.change(profile, "Quests", "QuestsCompleted")
	DataService.notify(profile.Player, "📜 Quest complete! 💎 " .. quest.Gems, "Reward")
end

local function claimDaily(profile)
	local data = profile.Data
	local now = os.time()
	local canClaim, day, _, streak = Formula.dailyStatus(data.Daily, now)
	if not canClaim then
		return
	end
	local reward = Config.Daily.Rewards[day]
	data.Daily.Last = now
	data.Daily.Streak = streak + 1
	DataService.grantReward(profile, reward)
	DataService.change(profile, "Daily")
	DataService.notify(
		profile.Player,
		"🎁 Day " .. day .. " reward!  " .. Rewards.describe(reward, data, profile.Session),
		"Reward"
	)
end

local function claimGift(profile, index)
	local session = profile.Session
	local gift = type(index) == "number" and Config.Gifts[index]
	if not gift or session.GiftsClaimed[index] then
		return
	end
	local elapsed = workspace:GetServerTimeNow() - session.JoinedAt
	if elapsed < gift.Minutes * 60 then
		return
	end
	session.GiftsClaimed[index] = true
	DataService.grantReward(profile, gift.Reward)
	DataService.notify(
		profile.Player,
		"🎁 Gift opened!  " .. Rewards.describe(gift.Reward, profile.Data, session),
		"Reward"
	)

	-- Once every gift is opened, start a fresh round.
	if not table.find(session.GiftsClaimed, false) then
		session.GiftsClaimed = table.create(#Config.Gifts, false)
		session.JoinedAt = workspace:GetServerTimeNow()
		DataService.change(profile, "Session.JoinedAt")
		DataService.notify(profile.Player, "🎁 All gifts opened — a new round of gifts has started!", "Info")
	end
	DataService.change(profile, "Session.GiftsClaimed")
end

local function redeemCode(player: Player, code): (boolean, string)
	local profile = DataService.get(player)
	if not profile or type(code) ~= "string" then
		return false, "Try again in a moment."
	end
	local now = os.clock()
	if now - (lastCodeAttempt[player] or 0) < 1 then
		return false, "Slow down!"
	end
	lastCodeAttempt[player] = now

	local normalized = string.upper((string.gsub(code, "%s", "")))
	local reward = Config.Codes[normalized]
	if not reward then
		return false, "That code doesn't exist."
	end
	local data = profile.Data
	if data.Codes[normalized] then
		return false, "You already redeemed this code."
	end
	data.Codes[normalized] = true
	DataService.grantReward(profile, reward)
	DataService.change(profile, "Codes")
	return true, "Redeemed!  " .. Rewards.describe(reward, data, profile.Session)
end

function RewardService.Init()
	DataService.onLoaded(fillQuests)
	DataService.onRelease(function(profile)
		lastCodeAttempt[profile.Player] = nil
	end)
end

function RewardService.Start()
	Actions.register("ClaimDaily", claimDaily)
	Actions.register("ClaimGift", claimGift)
	Actions.register("ClaimQuest", claimQuest)
	Net.func("RedeemCode").OnServerInvoke = redeemCode

	task.spawn(function()
		while true do
			task.wait(1)
			for player, profile in DataService.all() do
				local data = profile.Data
				data.Stats.TimePlayed += 1
				local boosts = data.Boosts
				for kind, remaining in boosts do
					if remaining > 0 then
						boosts[kind] = math.max(0, remaining - 1)
						DataService.change(profile, "Boosts")
						if boosts[kind] == 0 then
							local name = if kind == "Coins" then "2x Coins" else "2x Luck"
							DataService.notify(player, "⏰ Your " .. name .. " boost ended.", "Info")
						end
					end
				end
			end
		end
	end)
end

return RewardService
