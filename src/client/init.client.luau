--[[
	Client entry point: shows a loading screen until the profile arrives, then builds the UI
	and starts the controllers.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local State = require(script.State)
local Sound = require(script.Sound)
local UI = script.UI
local Controllers = script.Controllers

local Theme = require(UI.Theme)
local Util = require(UI.Util)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Loading screen
local loading = Util.new("ScreenGui", {
	Name = "Loading",
	DisplayOrder = 100,
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	Parent = playerGui,
})
local loadingFrame = Util.new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Theme.Colors.Background,
	Parent = loading,
})
Util.label({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromScale(0.6, 0.12),
	Text = "🥚 " .. Config.GameName .. " 🐾",
	TextColor3 = Theme.Colors.Gold,
	Parent = loadingFrame,
})
local loadingText = Util.label({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.58),
	Size = UDim2.fromScale(0.5, 0.05),
	Text = "Loading your pets…",
	Parent = loadingFrame,
})
task.spawn(function()
	local dots = 0
	while loading.Parent do
		dots = dots % 3 + 1
		loadingText.Text = "Loading your pets" .. string.rep(".", dots)
		task.wait(0.4)
	end
end)

State.start()

Util.startAutoScale()

local screen = Util.new("ScreenGui", {
	Name = "Main",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

local Windows = require(UI.Windows)
Windows.init(screen)

local Notifications = require(UI.Notifications)
local ShopWindow = require(UI.ShopWindow)
require(UI.PetsWindow).build()
require(UI.UpgradesWindow).build()
require(UI.RebirthWindow).build()
ShopWindow.build()
require(UI.QuestsWindow).build()
require(UI.DailyWindow).build()
require(UI.GiftsWindow).build()
require(UI.StatsWindow).build()
require(UI.CodesWindow).build()

local Input = require(Controllers.Input)
local Hud = require(UI.Hud)
Hud.build(screen, Input.tap, ShopWindow.open)
Notifications.build(screen)

local HatchOverlay = require(UI.HatchOverlay)
HatchOverlay.build()

local Chat = require(Controllers.Chat)
local World = require(Controllers.World)
Input.start()
require(Controllers.PetFollow).start()
World.start()
Chat.start()

Net.event("Notify").OnClientEvent:Connect(function(text, kind)
	Notifications.show(text, kind)
end)
Net.event("Hatched").OnClientEvent:Connect(function(eggId, results)
	Windows.closeAll()
	HatchOverlay.play(eggId, results)
end)
Net.event("Announce").OnClientEvent:Connect(function(text, color)
	Chat.system("🎉 " .. text, color)
	Notifications.banner("🎉 " .. text, color, 3)
end)
Net.event("OrbCollected").OnClientEvent:Connect(World.orbCollected)
Net.event("Effect").OnClientEvent:Connect(World.effect)

Util.tween(loadingFrame, 0.5, { BackgroundTransparency = 1 })
for _, label in loadingFrame:GetChildren() do
	if label:IsA("TextLabel") then
		Util.tween(label, 0.5, { TextTransparency = 1 })
	end
end
task.delay(0.5, function()
	loading:Destroy()
end)
Sound.play("Reveal", 1.3, 0.4)
