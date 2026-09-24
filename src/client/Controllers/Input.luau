--[[
	Tapping: the TAP button, a left click anywhere in the world, or R2 on a gamepad.
	The client shows the predicted coins instantly; the server grants the real amount.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formula = require(Shared.Formula)
local Net = require(Shared.Net)

local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.State)
local Hud = require(script.Parent.Parent.UI.Hud)

local Input = {}

local tapRemote = Net.event("Tap")
local minInterval = 1 / Config.Tap.MaxPerSecond
local lastTap = 0

function Input.tap()
	local now = os.clock()
	if now - lastTap < minInterval then
		return
	end
	lastTap = now
	tapRemote:FireServer()
	Hud.popTap(Formula.tapValue(State.Data, State.Session))
	Sound.play("Tap", 0.9 + math.random() * 0.3, 0.35)
end

function Input.start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			Input.tap()
		end
	end)
end

return Input
