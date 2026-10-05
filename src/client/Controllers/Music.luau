--!strict
--[[
	Background music. Each area plays its track from Config.Music (or the Default), crossfading
	when you walk into an area with a different track. The Music setting fades it in and out and the Music volume setting scales it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local State = require(script.Parent.Parent.State)

local Music = {}

local tracks: { [string]: Sound } = {}
local fades: { [Sound]: Tween } = {}
local currentId = ""
local watching = false

local function enabled(): boolean
	local settings = State.Data.Settings
	return not (settings and settings.Music == false)
end

local function fade(sound: Sound, volume: number)
	local running = fades[sound]
	if running then
		running:Cancel()
	end
	if volume > 0 and not sound.IsPlaying then
		sound:Play()
	end
	local tween = TweenService:Create(sound, TweenInfo.new(Config.Music.FadeSeconds), { Volume = volume })
	fades[sound] = tween
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and volume == 0 then
			sound:Pause()
		end
	end)
	tween:Play()
end

local function track(id: string): Sound
	local existing = tracks[id]
	if existing then
		return existing
	end
	local sound = Instance.new("Sound")
	sound.Name = "Music"
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	tracks[id] = sound
	return sound
end

local function refresh()
	local target = if enabled() then currentId else ""
	for id, sound in tracks do
		if id ~= target then
			fade(sound, 0)
		end
	end
	if target ~= "" then
		local setting = State.Data.Settings and State.Data.Settings.MusicVolume
		local scale = if type(setting) == "number" then math.clamp(setting, 0, 1) else 1
		fade(track(target), Config.Music.Volume * scale)
	end
end

-- Accepts "rbxassetid://123", "123" or 123 (and ignores stray spaces or brackets). "" = none.
local function soundId(value: any): string
	local digits = string.match(tostring(value or ""), "%d+")
	return if digits then "rbxassetid://" .. digits else ""
end

-- Called by the World controller whenever you walk into an area (by its Zones.luau Theme).
function Music.setArea(theme: string)
	local id = soundId(Config.Music.Areas[theme])
	if id == "" then
		id = soundId(Config.Music.Default)
	end
	if not watching then
		watching = true
		State.watch({ "Settings" }, refresh)
	end
	if id ~= currentId then
		currentId = id
		refresh()
	end
end

return Music
