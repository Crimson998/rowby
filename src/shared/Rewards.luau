--[[
	Describes reward tables (see Config.Daily) for the UI. Granting happens on the server in
	Services/Grant so a reward always shows and pays out the same thing.
]]

local Format = require(script.Parent.Format)
local Formula = require(script.Parent.Formula)
local Pets = require(script.Parent.Pets)

local Rewards = {}

function Rewards.parts(reward, data, session): { string }
	local parts = {}
	if reward.Gems then
		table.insert(parts, "💎 " .. Format.number(reward.Gems))
	end
	if reward.CoinSeconds then
		local coins = if data and session
			then Format.number(Formula.rewardCoins(data, session, reward.CoinSeconds))
			else "Coins"
		table.insert(parts, "🪙 " .. coins)
	end
	if reward.CoinBoostMinutes then
		table.insert(parts, "⚡ 2x Coins " .. reward.CoinBoostMinutes .. "m")
	end
	if reward.LuckBoostMinutes then
		table.insert(parts, "🍀 2x Luck " .. reward.LuckBoostMinutes .. "m")
	end
	if reward.Pet and Pets[reward.Pet] then
		table.insert(parts, "🐾 " .. Pets[reward.Pet].Name)
	end
	return parts
end

-- Largest value each field of a live (admin-created) code may carry.
Rewards.LiveLimits = {
	Gems = 10000,
	CoinSeconds = 3600,
	CoinBoostMinutes = 120,
	LuckBoostMinutes = 120,
}

-- Turns untrusted input (admin panel, DataStore) into a reward table, or nil when it grants
-- nothing. Unknown fields are dropped, values are floored and clamped to LiveLimits.
function Rewards.sanitize(input: any): { [string]: number }?
	if type(input) ~= "table" then
		return nil
	end
	local reward = {}
	local any = false
	for key, limit in Rewards.LiveLimits do
		local value = tonumber(input[key])
		if value and value == value and value >= 1 then
			reward[key] = math.floor(math.min(value, limit))
			any = true
		end
	end
	return if any then reward else nil
end

function Rewards.describe(reward, data, session): string
	return table.concat(Rewards.parts(reward, data, session), "  ")
end

return Rewards
