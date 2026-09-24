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

function Rewards.describe(reward, data, session): string
	return table.concat(Rewards.parts(reward, data, session), "  ")
end

return Rewards
