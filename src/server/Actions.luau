--[[
	Routes the client's Action remote to handlers registered by services. Handlers receive the
	caller's loaded profile, so unloaded players and unknown actions are ignored centrally, and
	each player is rate limited so a modified client can't flood the server with requests.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)

local DataService = require(script.Parent.Services.DataService)

local Actions = {}

-- Normal play (clicking buttons, auto hatch) stays far below this.
local RATE_PER_SECOND = 15
local BURST = 30

local handlers: { [string]: (any, ...any) -> () } = {}
local buckets: { [Player]: { Tokens: number, Last: number } } = {}

local function allow(player: Player): boolean
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { Tokens = BURST, Last = now }
		buckets[player] = bucket
	end
	bucket.Tokens = math.min(BURST, bucket.Tokens + (now - bucket.Last) * RATE_PER_SECOND)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

function Actions.register(name: string, handler: (any, ...any) -> ())
	assert(handlers[name] == nil, "Duplicate action " .. name)
	handlers[name] = handler
end

function Actions.listen()
	Net.event("Action").OnServerEvent:Connect(function(player, name, ...)
		if type(name) ~= "string" or not allow(player) then
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
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return Actions
