--[[
	Server entry point. Services initialise in order (Init may register onLoaded handlers, which
	then run in the same order), then all start.
]]

local Services = script.Services
local Actions = require(script.Actions)

local ordered = {
	require(Services.DataService),
	require(Services.WorldService),
	require(Services.MonetizationService),
	require(Services.PetService),
	require(Services.EconomyService),
	require(Services.RewardService),
	require(Services.LeaderboardService),
	require(Services.SocialService),
}

for _, service in ordered do
	service.Init()
end

Actions.listen()

for _, service in ordered do
	task.spawn(service.Start)
end
