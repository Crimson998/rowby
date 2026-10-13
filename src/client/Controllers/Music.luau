--!strict
--[[
	Background music and ambient sound. Each area plays its track from Config.Music (or the Default)
	and its loop from Config.Ambience, crossfading when you walk into an area with a different one.
	The Music setting fades both in and out and the Music volume setting scales both.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local State = require(script.Parent.Parent.State)

local Music = {}

local watching = false

type Layer = {
	tracks: { [string]: Sound },
	fades: { [Sound]: Tween },
	currentId: string,
	name: string,
	settings: any,
}

local function newLayer(name: string, settings: any): Layer
	return { tracks = {}, fades = {}, currentId = "", name = name, settings = settings }
end

-- Music and ambience are separate layers that play together; both obey the Music settings.
local layers = {
	newLayer("Music", Config.Music),
	newLayer("Ambience", Config.Ambience),
}

local function enabled(): boolean
	local settings = State.Data.Settings
	return not (settings and settings.Music == false)
end

local function fade(layer: Layer, sound: Sound, volume: number)
	local running = layer.fades[sound]
	if running then
		running:Cancel()
	end
	if volume > 0 and not sound.IsPlaying then
		sound:Play()
	end
	local tween = TweenService:Create(sound, TweenInfo.new(Config.Music.FadeSeconds), { Volume = volume })
	layer.fades[sound] = tween
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and volume == 0 then
			sound:Pause()
		end
	end)
	tween:Play()
end

local function track(layer: Layer, id: string): Sound
	local existing = layer.tracks[id]
	if existing then
		return existing
	end
	local sound = Instance.new("Sound")
	sound.Name = layer.name
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	layer.tracks[id] = sound
	return sound
end

local function refresh()
	local setting = State.Data.Settings and State.Data.Settings.MusicVolume
	local scale = if type(setting) == "number" then math.clamp(setting, 0, 1) else 1
	for _, layer in layers do
		local target = if enabled() then layer.currentId else ""
		for id, sound in layer.tracks do
			if id ~= target then
				fade(layer, sound, 0)
			end
		end
		if target ~= "" then
			fade(layer, track(layer, target), layer.settings.Volume * scale)
		end
	end
end

-- Accepts "rbxassetid://123", "123" or 123 (and ignores stray spaces or brackets). "" = none.
local function soundId(value: any): string
	local digits = string.match(tostring(value or ""), "%d+")
	return if digits then "rbxassetid://" .. digits else ""
end

-- Called by the World controller whenever you walk into an area (by its Zones.luau Theme).
function Music.setArea(theme: string)
	if not watching then
		watching = true
		State.watch({ "Settings" }, refresh)
	end
	local changed = false
	for _, layer in layers do
		local id = soundId(layer.settings.Areas[theme])
		if id == "" then
			id = soundId(layer.settings.Default)
		end
		if id ~= layer.currentId then
			layer.currentId = id
			changed = true
		end
	end
	if changed then
		refresh()
	end
end

return Music
