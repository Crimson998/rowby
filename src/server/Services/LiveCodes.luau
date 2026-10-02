--[[
	Codes stored in a DataStore so they can be added and removed from the admin panel without
	publishing an update. Config.Codes still works and wins on a name clash. Servers refresh the
	list every minute; in Studio (or if DataStores fail) codes live in memory only.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rewards = require(Shared.Rewards)

local DataService = require(script.Parent.DataService)

local LiveCodes = {}

local STORE_NAME = "TapAndHatch_LiveCodes_v1"
local KEY = "Codes"
local REFRESH_SECONDS = 60
local MAX_CODES = 100

local store: DataStore? = nil
local codes: { [string]: { [string]: number } } = {}

function LiveCodes.normalize(code: any): string?
	if type(code) ~= "string" then
		return nil
	end
	local normalized = string.upper((string.gsub(code, "%s", "")))
	if #normalized < 3 or #normalized > 20 or string.find(normalized, "[^%w]") then
		return nil
	end
	return normalized
end

function LiveCodes.get(code: string): { [string]: number }?
	return Config.Codes[code] or codes[code]
end

function LiveCodes.list(): { [string]: { [string]: number } }
	return codes
end

local function refresh()
	if not store then
		return
	end
	local ok, result = pcall(function()
		return (store :: DataStore):GetAsync(KEY)
	end)
	if not ok then
		warn("[LiveCodes] refresh failed: " .. tostring(result))
		return
	end
	local fresh = {}
	if type(result) == "table" then
		for code, reward in result do
			local clean = Rewards.sanitize(reward)
			if clean and LiveCodes.normalize(code) == code then
				fresh[code] = clean
			end
		end
	end
	codes = fresh
end

-- Applies `change` to the stored list (and the local copy). Returns false, reason on failure.
local function update(change: (list: { [string]: any }) -> string?): (boolean, string?)
	local failure: string? = nil
	local function apply(list: any)
		local copy = if type(list) == "table" then table.clone(list) else {}
		failure = change(copy)
		return copy
	end
	if store then
		local ok, result = pcall(function()
			return (store :: DataStore):UpdateAsync(KEY, function(old)
				local new = apply(old)
				if failure then
					return nil
				end
				return new
			end)
		end)
		if not ok then
			return false, "DataStore error: " .. tostring(result)
		end
		if failure then
			return false, failure
		end
		refresh()
	else
		local new = apply(codes)
		if failure then
			return false, failure
		end
		codes = new
	end
	return true, nil
end

function LiveCodes.add(code: string, reward: { [string]: number }): (boolean, string?)
	return update(function(list)
		if Config.Codes[code] then
			return "That name is already a built-in code."
		end
		local count = 0
		for _ in list do
			count += 1
		end
		if list[code] == nil and count >= MAX_CODES then
			return "Too many live codes (max " .. MAX_CODES .. ")."
		end
		list[code] = reward
		return nil
	end)
end

function LiveCodes.remove(code: string): (boolean, string?)
	return update(function(list)
		if list[code] == nil then
			return "No live code named " .. code .. "."
		end
		list[code] = nil
		return nil
	end)
end

function LiveCodes.Init()
	if not DataService.isMock() then
		local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
		if ok then
			store = result
		end
	end
end

function LiveCodes.Start()
	if not store then
		return
	end
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return LiveCodes
