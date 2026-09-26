--[[
	⚙️ Settings: hatch animation, auto-equip, auto-delete by rarity, sounds and other players'
	pets. Saved on the server with the rest of your data.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local Actions = require(script.Parent.Parent.Actions)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Windows = require(script.Parent.Windows)

local SettingsWindow = {}

local NAME = "Settings"

function SettingsWindow.build()
	local body = Windows.create(NAME, "⚙️ Settings", Theme.Colors.Gray, Vector2.new(560, 470))
	local list = Util.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	}, { Util.list(Enum.FillDirection.Vertical, 8) })

	local order = 0
	local refreshers: { () -> () } = {}

	local function row(title: string, hint: string?): Frame
		order += 1
		local frame = Util.new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, if hint then 64 else 48),
			BackgroundColor3 = Theme.Colors.Panel,
			Parent = list,
		}, { Util.corner(12) })
		Util.label({
			Size = UDim2.new(0.5, -12, 0, 26),
			Position = UDim2.fromOffset(12, if hint then 8 else 11),
			Text = title,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		if hint then
			Util.label({
				Size = UDim2.new(0.5, -12, 0, 20),
				Position = UDim2.fromOffset(12, 36),
				Text = hint,
				TextColor3 = Theme.Colors.SubText,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = frame,
			})
		end
		return frame
	end

	local function toggle(title: string, hint: string?, key: string)
		local frame = row(title, hint)
		local button = Util.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(110, 38),
			Parent = frame,
		}, function()
			Actions("SetSetting", key, not State.Data.Settings[key])
		end)
		table.insert(refreshers, function()
			local on = State.Data.Settings[key] == true
			button.Text = if on then "ON" else "OFF"
			button.BackgroundColor3 = if on then Theme.Colors.Green else Theme.Colors.Disabled
		end)
	end

	-- Hatch animation: Full / Fast / Off
	do
		local frame = row("Hatch animation", "Fast skips the wobble; Off shows a message")
		local choices = { "Full", "Fast", "Off" }
		local buttons = {}
		for index, choice in choices do
			buttons[choice] = Util.button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10 - (#choices - index) * 78, 0.5, 0),
				Size = UDim2.fromOffset(72, 38),
				Text = choice,
				Parent = frame,
			}, function()
				Actions("SetSetting", "HatchAnimation", choice)
			end)
		end
		table.insert(refreshers, function()
			for choice, button in buttons do
				button.BackgroundColor3 = if State.Data.Settings.HatchAnimation == choice
					then Theme.Colors.Blue
					else Theme.Colors.Disabled
			end
		end)
	end

	toggle("Auto-equip best", "Equip your strongest pets after hatching", "AutoEquip")

	-- Auto-delete by rarity
	do
		local frame = row("Auto-delete when hatched", "New pets are always kept first time")
		frame.Size = UDim2.new(1, -12, 0, 112)
		local grid = Util.new("Frame", {
			Position = UDim2.fromOffset(10, 64),
			Size = UDim2.new(1, -20, 0, 40),
			BackgroundTransparency = 1,
			Parent = frame,
		}, { Util.list(Enum.FillDirection.Horizontal, 8) })
		local buttons = {}
		for index, rarity in Config.Pets.AutoDeletable do
			buttons[rarity] = Util.button({
				LayoutOrder = index,
				Size = UDim2.fromOffset(118, 38),
				Text = rarity,
				Parent = grid,
			}, function()
				Actions("SetAutoDelete", rarity, not State.Data.Settings.AutoDelete[rarity])
			end)
		end
		table.insert(refreshers, function()
			for rarity, button in buttons do
				local on = State.Data.Settings.AutoDelete[rarity] == true
				button.Text = (if on then "🗑 " else "") .. rarity
				button.BackgroundColor3 = if on then Theme.Colors.Red else Theme.Colors.Disabled
				local stroke = button:FindFirstChild("Border") :: UIStroke
				stroke.Color = Config.Rarities[rarity].Color
			end
		end)
	end

	toggle("Sound effects", nil, "Sounds")
	toggle("Show other players' pets", "Turn off if the game feels slow", "ShowOtherPets")

	State.watch({ "Settings" }, function()
		for _, refresh in refreshers do
			refresh()
		end
	end)
end

return SettingsWindow
