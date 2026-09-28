--[[
	One-time milestone rewards (see Shared/Achievements). Claiming is player-initiated, like
	quests, so the client shows a satisfying "Claim" moment instead of gems silently appearing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared.Achievements)

local Actions = require(script.Parent.Parent.Actions)
local DataService = require(script.Parent.DataService)

local AchievementService = {}

local function claimAchievement(profile, id)
	local template = type(id) == "string" and Achievements.ById[id]
	if not template then
		return
	end
	local data = profile.Data
	if Achievements.isClaimed(data, template) or Achievements.progress(data, template) < template.Goal then
		return
	end
	data.Achievements[id] = true
	DataService.addGems(profile, template.Gems)
	DataService.change(profile, "Achievements")
	DataService.notify(profile.Player, "🏆 Achievement complete! 💎 " .. template.Gems, "Reward")
end

function AchievementService.Init() end

function AchievementService.Start()
	Actions.register("ClaimAchievement", claimAchievement)
end

return AchievementService
