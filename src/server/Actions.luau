--[[
	Routes the client's Action remote to handlers registered by services. Handlers receive the
	caller's loaded profile, so unloaded players and unknown actions are ignored centrally.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)

local DataService = require(script.Parent.Services.DataService)

local Actions = {}

local handlers: { [string]: (any, ...any) -> () } = {}

function Actions.register(name: string, handler: (any, ...any) -> ())
	assert(handlers[name] == nil, "Duplicate action " .. name)
	handlers[name] = handler
end

function Actions.listen()
	Net.event("Action").OnServerEvent:Connect(function(player, name, ...)
		if type(name) ~= "string" then
			return
		end
		local handler = handlers[name]
		local profile = DataService.get(player)
		if not handler or not profile then
			return
		end
		local ok, err = pcall(handler, profile, ...)
		if not ok then
			warn(string.format("[Actions] %s from %s failed: %s", name, player.Name, tostring(err)))
		end
	end)
end

return Actions
