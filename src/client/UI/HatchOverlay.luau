--[[
	Full-screen egg hatch: the egg wobbles harder and harder, flashes, then reveals the pet with
	its rarity. Click to skip. A new hatch while one is playing replaces it immediately.
	Settings.HatchAnimation picks "Full", "Fast" (no wobble, short reveal) or "Off" (a toast).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Formula = require(Shared.Formula)
local Pets = require(Shared.Pets)

local PetModels = require(script.Parent.Parent.PetModels)
local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.State)
local Notifications = require(script.Parent.Notifications)
local Viewport = require(script.Parent.Parent.Viewport)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local HatchOverlay = {}

local SHAKE_TIME = 1.2
local HOLD_TIME = 2.2
local FAST_HOLD_TIME = 0.9

type Result = { Id: string, Uid: string?, New: boolean, Deleted: boolean? }

local gui: ScreenGui
local container: Frame
local flash: Frame
local token = 0
local skip = false

function HatchOverlay.build()
	gui = Util.new("ScreenGui", {
		Name = "Hatch",
		DisplayOrder = 20,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local background = Util.new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Text = "",
		AutoButtonColor = false,
		Parent = gui,
	})
	background.Activated:Connect(function()
		skip = true
	end)
	container = Util.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(820, 360),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Util.list(Enum.FillDirection.Horizontal, 20, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	Util.autoScale(container)
	flash = Util.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = gui,
	})
end

function HatchOverlay.isPlaying(): boolean
	return gui ~= nil and gui.Enabled
end

-- "Off" mode: one toast instead of the overlay.
local function toast(results: { Result })
	local names = {}
	local deleted = 0
	local best = 1
	for _, result in results do
		local pet = Pets[result.Id]
		best = math.max(best, table.find(Config.RarityOrder, pet.Rarity) or 1)
		if result.Deleted then
			deleted += 1
		else
			table.insert(names, (if result.New then "NEW " else "") .. pet.Name)
		end
	end
	local text = "🥚 " .. (if #names > 0 then table.concat(names, ", ") else "")
	if deleted > 0 then
		text ..= (if #names > 0 then "  " else "") .. "🗑 " .. deleted .. " auto-deleted"
	end
	Notifications.show(text, if best >= 4 then "Reward" else "Info")
	Sound.play("Hatch", 1.2, 0.35)
end

function HatchOverlay.play(eggId: string, results: { Result })
	local mode = State.Data.Settings and State.Data.Settings.HatchAnimation or "Full"
	if mode == "Off" then
		toast(results)
		return
	end
	token += 1
	local myToken = token
	skip = false
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	gui.Enabled = true

	local slots = {}
	for index, result in results do
		local slot = Util.new("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(250, 340),
			BackgroundTransparency = 1,
			Parent = container,
		})
		local viewport = Viewport.new({ Size = UDim2.fromOffset(250, 250), Parent = slot })
		Viewport.show(viewport, PetModels.egg(eggId), 6.5)
		local name =
			Util.label({ Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 252), Text = "", Parent = slot })
		local rarity =
			Util.label({ Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 292), Text = "", Parent = slot })
		local badge = Util.label({
			Size = UDim2.fromOffset(90, 32),
			Position = UDim2.new(1, -90, 0, 10),
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.Colors.Red,
			Text = "NEW!",
			Rotation = 10,
			Visible = false,
			Parent = slot,
		})
		Util.corner(10).Parent = badge
		slots[index] = { Viewport = viewport, Name = name, Rarity = rarity, Badge = badge, Result = result }
	end

	Sound.play("Hatch", 1, 0.6)
	-- Wobble (skipped in Fast mode)
	local start = os.clock()
	while mode == "Full" and os.clock() - start < SHAKE_TIME do
		if skip or token ~= myToken then
			break
		end
		local t = os.clock() - start
		local angle = math.sin(t * 28) * (t / SHAKE_TIME) * 0.45
		for _, slot in slots do
			local model = slot.Viewport:FindFirstChildOfClass("Model")
			if model then
				model:PivotTo(CFrame.Angles(0, 0, angle))
			end
		end
		RunService.RenderStepped:Wait()
	end
	if token ~= myToken then
		return
	end

	-- Reveal
	flash.BackgroundTransparency = 0.05
	Util.tween(flash, 0.45, { BackgroundTransparency = 1 })
	local best = 0
	for _, slot in slots do
		local pet = Pets[slot.Result.Id]
		local rarity = Config.Rarities[pet.Rarity]
		Viewport.show(slot.Viewport, PetModels.pet(slot.Result.Id, 1), 5.2)
		slot.Name.Text = pet.Name
		slot.Rarity.Text = pet.Rarity .. "  ·  +" .. Format.number(Formula.petPower(slot.Result.Id, 1)) .. "x"
		slot.Rarity.TextColor3 = rarity.Color
		if slot.Result.Deleted then
			slot.Rarity.Text = "🗑 Auto-deleted"
			slot.Rarity.TextColor3 = Theme.Colors.SubText
			slot.Viewport.ImageTransparency = 0.6
		end
		slot.Badge.Visible = slot.Result.New
		best = math.max(best, table.find(Config.RarityOrder, pet.Rarity) or 1)
	end
	Sound.play("Reveal", if best >= 4 then 1 else 1.25, if best >= 4 then 0.8 else 0.5)

	skip = false
	local revealStart = os.clock()
	local hold = if mode == "Fast" then FAST_HOLD_TIME else HOLD_TIME
	while os.clock() - revealStart < hold do
		if skip or token ~= myToken then
			break
		end
		local angle = (os.clock() - revealStart) * 1.6
		for _, slot in slots do
			Viewport.spin(slot.Viewport, math.sin(angle) * 0.6)
		end
		RunService.RenderStepped:Wait()
	end
	if token == myToken then
		gui.Enabled = false
	end
end

return HatchOverlay
