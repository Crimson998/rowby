local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local Sound = {}

local POOL_SIZE = 5
local pools: { [string]: { Index: number, Sounds: { Sound } } } = {}

function Sound.play(name: string, pitch: number?, volume: number?)
	local id = Config.Sounds[name]
	if not id then
		return
	end
	local pool = pools[name]
	if not pool then
		pool = { Index = 0, Sounds = {} }
		for index = 1, POOL_SIZE do
			local sound = Instance.new("Sound")
			sound.Name = name
			sound.SoundId = id
			sound.Parent = SoundService
			pool.Sounds[index] = sound
		end
		pools[name] = pool
	end
	pool.Index = pool.Index % POOL_SIZE + 1
	local sound = pool.Sounds[pool.Index]
	sound.PlaybackSpeed = pitch or 1
	sound.Volume = volume or 0.5
	sound.TimePosition = 0
	sound:Play()
end

return Sound
