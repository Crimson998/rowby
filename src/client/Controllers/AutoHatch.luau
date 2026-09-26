--[[
	Free Auto Hatch: a button appears beside the TAP button while you stand at an unlocked egg.
	When on, it keeps hatching (3 at a time with Triple Hatch) until you walk away, run out of
	coins or fill your pet storage. It waits for each hatch animation to finish.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Eggs = require(Shared.Eggs)
local Formula = require(Shared.Formula)

local Actions = require(script.Parent.Parent.Actions)
local State = require(script.Parent.Parent.State)
local HatchOverlay = require(script.Parent.Parent.UI.HatchOverlay)
local Hud = require(script.Parent.Parent.UI.Hud)
local Notifications = require(script.Parent.Parent.UI.Notifications)
local Theme = require(script.Parent.Parent.UI.Theme)
local Util = require(script.Parent.Parent.UI.Util)

local AutoHatch = {}

local RANGE = 14

local player = Players.LocalPlayer
local enabled = false
local nearEgg: string? = nil
local button: TextButton

local function findNearbyEgg(): string?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	for _, stand in CollectionService:GetTagged("EggStand") do
		local eggId = stand:GetAttribute("EggId")
		local egg = type(eggId) == "string" and Eggs.ById[eggId]
		local eggModel = stand:FindFirstChild("Egg") :: Model?
		if egg and eggModel and egg.Zone <= State.Data.HighestZone then
			local offset = eggModel:GetPivot().Position - root.Position
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= RANGE then
				return eggId
			end
		end
	end
	return nil
end

local function refreshButton()
	button.Visible = nearEgg ~= nil
	button.Text = if enabled then "🥚 Auto: ON" else "🥚 Auto Hatch"
	button.BackgroundColor3 = if enabled then Theme.Colors.Green else Theme.Colors.Purple
end

local function stop(reason: string?)
	if enabled and reason then
		Notifications.show("🥚 Auto hatch stopped: " .. reason, "Info")
	end
	enabled = false
	refreshButton()
end

-- One auto-hatch attempt; returns false (after stopping) when it can't continue.
local function tryHatch(eggId: string): boolean
	local data = State.Data
	local egg = Eggs.ById[eggId]
	local count = if State.Session.Passes.TripleHatch then 3 else 1
	if data.Coins < egg.Price * count then
		count = 1
	end
	if data.Coins < egg.Price * count then
		stop("out of coins.")
		return false
	end
	if Formula.petCount(data) >= Config.Pets.Storage then
		stop("pet storage is full.")
		return false
	end
	Actions("Hatch", eggId, count)
	return true
end

function AutoHatch.start()
	local holder = Hud.TapArea :: Frame
	button = Util.button({
		Name = "AutoHatch",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0, -12, 1, -20),
		Size = UDim2.fromOffset(150, 48),
		Visible = false,
		Parent = holder,
	}, function()
		enabled = not enabled
		refreshButton()
		local settings = State.Data.Settings
		if enabled and settings and settings.HatchAnimation == "Full" then
			Notifications.show(
				"Tip: set Hatch animation to Fast or Off in ⚙️ Settings to auto hatch faster.",
				"Info"
			)
		end
	end)
	refreshButton()

	-- Watch where the player is.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local egg = findNearbyEgg()
			if egg ~= nearEgg then
				nearEgg = egg
				if not egg then
					stop(nil)
				end
				refreshButton()
			end
		end
	end)

	-- Hatch loop.
	task.spawn(function()
		local lastHatch = 0
		while true do
			task.wait(0.1)
			local eggId = nearEgg
			if not enabled or not eggId then
				continue
			end
			if HatchOverlay.isPlaying() or os.clock() - lastHatch < Config.Pets.HatchCooldown + 0.15 then
				continue
			end
			if tryHatch(eggId) then
				lastHatch = os.clock()
				-- Give the server a moment to reply so the animation check above sees it.
				task.wait(0.4)
			end
		end
	end)
end

return AutoHatch
