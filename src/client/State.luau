--[[
	Client copy of the player's profile, kept in sync by the server's Sync remote.
	Data keys are watched by name ("Coins"); session keys with a prefix ("Session.Passes").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)

type Listener = { Keys: { [string]: boolean }?, Fn: (changed: { [string]: boolean }) -> () }

local State = {
	Data = {} :: any,
	Session = {} :: any,
	Ready = false,
}

local listeners: { Listener } = {}
local readyEvent = Instance.new("BindableEvent")

local function dispatch(changed: { [string]: boolean })
	for _, listener in listeners do
		local keys = listener.Keys
		if keys == nil then
			task.spawn(listener.Fn, changed)
			continue
		end
		for key in changed do
			if keys[key] then
				task.spawn(listener.Fn, changed)
				break
			end
		end
	end
end

-- Calls fn now (once ready) and whenever any of `keys` change. nil keys = every change.
function State.watch(keys: { string }?, fn: (changed: { [string]: boolean }) -> ()): () -> ()
	local set: { [string]: boolean }? = nil
	if keys then
		local newSet = {}
		for _, key in keys do
			newSet[key] = true
		end
		set = newSet
	end
	local listener: Listener = { Keys = set, Fn = fn }
	table.insert(listeners, listener)
	if State.Ready then
		task.spawn(fn, {})
	end
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

function State.start()
	Net.event("Sync").OnClientEvent:Connect(function(payload)
		local changed = {}
		if payload.Full then
			State.Data = payload.Data
			State.Session = payload.Session
			for key in State.Data do
				changed[key] = true
			end
			for key in State.Session do
				changed["Session." .. key] = true
			end
		elseif State.Ready then
			for key, value in payload.Data do
				State.Data[key] = value
				changed[key] = true
			end
			for key, value in payload.Session do
				State.Session[key] = value
				changed["Session." .. key] = true
			end
		else
			return
		end
		if not State.Ready then
			State.Ready = true
			readyEvent:Fire()
		end
		dispatch(changed)
	end)
	if not State.Ready then
		readyEvent.Event:Wait()
	end
end

return State
