--[[
	Saves player preferences from the ⚙️ Settings window. Every value is validated here, since
	settings like AutoDelete change what the server does with hatched pets.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local Actions = require(script.Parent.Parent.Actions)
local DataService = require(script.Parent.DataService)

local SettingsService = {}

local VALIDATORS: { [string]: (any) -> boolean } = {
	HatchAnimation = function(value)
		return value == "Full" or value == "Fast" or value == "Off"
	end,
	AutoEquip = function(value)
		return type(value) == "boolean"
	end,
	Sounds = function(value)
		return type(value) == "boolean"
	end,
	ShowOtherPets = function(value)
		return type(value) == "boolean"
	end,
}

local function setSetting(profile, key, value)
	local validate = type(key) == "string" and VALIDATORS[key]
	if not validate or not validate(value) then
		return
	end
	profile.Data.Settings[key] = value
	DataService.change(profile, "Settings")
	if key == "AutoEquip" and value == true then
		local PetService = require(script.Parent.PetService) :: any
		PetService.equipBest(profile)
	end
end

local function setAutoDelete(profile, rarity, enabled)
	if type(rarity) ~= "string" or type(enabled) ~= "boolean" then
		return
	end
	if not table.find(Config.Pets.AutoDeletable, rarity) then
		return
	end
	profile.Data.Settings.AutoDelete[rarity] = enabled
	DataService.change(profile, "Settings")
end

function SettingsService.Init() end

function SettingsService.Start()
	Actions.register("SetSetting", setSetting)
	Actions.register("SetAutoDelete", setAutoDelete)
end

return SettingsService
