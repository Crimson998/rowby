--[[
	🛠 Admin panel for testing and debugging. Only shown to admins (see AdminService); every
	button runs a server command that re-checks permission. Open with the 🛠 button or F2.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Eggs = require(Shared.Eggs)
local Net = require(Shared.Net)
local Pets = require(Shared.Pets)
local Products = require(Shared.Products)
local Zones = require(Shared.Zones)

local PetModels = require(script.Parent.Parent.PetModels)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Windows = require(script.Parent.Windows)

local AdminWindow = {}

local NAME = "Admin"

local adminRemote = Net.func("AdminCommand")
local output: TextLabel
local busy = false

local function run(name: string, ...: any)
	if busy then
		return
	end
	busy = true
	output.Text = "⏳ " .. name .. "…"
	output.TextColor3 = Theme.Colors.SubText
	local args = table.pack(...)
	local ok, success, message = pcall(function()
		return adminRemote:InvokeServer(name, table.unpack(args, 1, args.n))
	end)
	busy = false
	if not ok then
		success, message = false, tostring(success)
	end
	output.Text = (if success then "✅ " else "❌ ") .. tostring(message or name)
	output.TextColor3 = if success then Theme.Colors.Text else Theme.Colors.Red
end

function AdminWindow.build(): ()
	local body = Windows.create(NAME, "🛠 Admin", Theme.Colors.Red, Vector2.new(780, 540))

	local list = Util.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -128),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	}, { Util.list(Enum.FillDirection.Vertical, 6) })

	local outputFrame = Util.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 118),
		BackgroundColor3 = Theme.Colors.Panel,
		Parent = body,
	}, { Util.corner(12), Util.padding(8) })
	output = Util.label({
		Size = UDim2.fromScale(1, 1),
		Text = "Admin commands change your own data. Results show here.",
		TextScaled = false,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = outputFrame,
	})

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local function section(title: string): Frame
		Util.label({
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -12, 0, 26),
			Text = title,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = list,
		})
		return Util.new("Frame", {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -12, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = list,
		}, {
			Util.new("UIGridLayout", {
				CellSize = UDim2.fromOffset(170, 36),
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
	end

	local function button(parent: Instance, text: string, color: Color3?, onClick: (TextButton) -> ()): TextButton
		local newButton: TextButton
		newButton = Util.button({
			LayoutOrder = nextOrder(),
			Text = text,
			Color = color or Theme.Colors.Blue,
			Parent = parent,
		}, function()
			onClick(newButton)
		end)
		return newButton
	end

	-- A "< value >" picker; returns a function giving the current index.
	local function picker(parent: Instance, count: number, label: (number) -> (string, Color3?)): () -> number
		local index = 1
		local frame = Util.new("Frame", { LayoutOrder = nextOrder(), BackgroundTransparency = 1, Parent = parent })
		local text = Util.label({
			Size = UDim2.new(1, -60, 1, 0),
			Position = UDim2.fromOffset(30, 0),
			Text = "",
			Parent = frame,
		})
		local function refresh()
			local value, color = label(index)
			text.Text = value
			text.TextColor3 = color or Theme.Colors.Text
		end
		Util.button(
			{ Size = UDim2.new(0, 28, 1, 0), Text = "<", Color = Theme.Colors.PanelLight, Parent = frame },
			function()
				index = (index - 2) % count + 1
				refresh()
			end
		)
		Util.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 28, 1, 0),
			Text = ">",
			Color = Theme.Colors.PanelLight,
			Parent = frame,
		}, function()
			index = index % count + 1
			refresh()
		end)
		refresh()
		return function()
			return index
		end
	end

	local function numberBox(parent: Instance, placeholder: string, default: string): TextBox
		return Util.new("TextBox", {
			LayoutOrder = nextOrder(),
			BackgroundColor3 = Theme.Colors.Panel,
			Font = Theme.Font,
			PlaceholderText = placeholder,
			PlaceholderColor3 = Theme.Colors.SubText,
			Text = default,
			TextColor3 = Theme.Colors.Text,
			TextScaled = true,
			ClearTextOnFocus = false,
			Parent = parent,
		}, { Util.corner(10), Util.padding(6) })
	end

	-- Currency
	local currency = section("💰 Currency")
	for _, entry in { { "+1K 🪙", 1e3 }, { "+1M 🪙", 1e6 }, { "+1B 🪙", 1e9 }, { "+1T 🪙", 1e12 } } do
		button(currency, entry[1], Theme.Colors.Orange, function()
			run("AddCoins", entry[2])
		end)
	end
	for _, entry in { { "+100 💎", 100 }, { "+10K 💎", 1e4 } } do
		button(currency, entry[1], Theme.Colors.Blue, function()
			run("AddGems", entry[2])
		end)
	end
	local amountBox = numberBox(currency, "Amount (e.g. 5e6)", "")
	button(currency, "Add coins", Theme.Colors.Orange, function()
		run("AddCoins", amountBox.Text)
	end)
	button(currency, "Add gems", Theme.Colors.Blue, function()
		run("AddGems", amountBox.Text)
	end)
	button(currency, "Coins & gems → 0", Theme.Colors.Red, function()
		run("ResetCurrency")
	end)

	-- Pets
	local pets = section("🐾 Pets")
	local petOrder = PetModels.indexOrder()
	local petIndex = picker(pets, #petOrder, function(index)
		local pet = Pets[petOrder[index]]
		return pet.Name, Config.Rarities[pet.Rarity].Color
	end)
	local tierIndex = picker(pets, #Config.Tiers, function(index)
		local tier = Config.Tiers[index]
		return (if tier.Icon ~= "" then tier.Icon .. " " else "") .. tier.Name, tier.Color
	end)
	local countBox = numberBox(pets, "How many", "1")
	button(pets, "Give pet", Theme.Colors.Green, function()
		run("GivePet", petOrder[petIndex()], tierIndex(), countBox.Text)
	end)
	button(pets, "Give every pet", Theme.Colors.Green, function()
		run("GiveEveryPet")
	end)
	button(pets, "Clear all pets", Theme.Colors.Red, function(self)
		if self.Text ~= "Tap again!" then
			self.Text = "Tap again!"
			task.delay(3, function()
				self.Text = "Clear all pets"
			end)
			return
		end
		self.Text = "Clear all pets"
		run("ClearPets")
	end)

	-- Luck & boosts
	local luck = section("🍀 Luck & boosts")
	button(luck, "Luck +10 levels", Theme.Colors.Green, function()
		run("AddLuckLevels", 10)
	end)
	button(luck, "Luck +50 levels", Theme.Colors.Green, function()
		run("AddLuckLevels", 50)
	end)
	button(luck, "Luck max level", Theme.Colors.Green, function()
		run("SetLuckLevel", Config.Luck.MaxLevel)
	end)
	button(luck, "Luck level 0", Theme.Colors.Red, function()
		run("SetLuckLevel", 0)
	end)
	button(luck, "2x Coins +15m", Theme.Colors.Orange, function()
		run("AddBoost", "Coins", 15)
	end)
	button(luck, "2x Luck +15m", Theme.Colors.Green, function()
		run("AddBoost", "Luck", 15)
	end)
	button(luck, "Clear boosts", Theme.Colors.Red, function()
		run("ClearBoosts")
	end)

	-- Progress
	local progress = section("📈 Progress")
	button(progress, "Unlock all areas", Theme.Colors.Purple, function()
		run("SetHighestZone", #Zones.List)
	end)
	button(progress, "Lock areas (→ 1)", Theme.Colors.Red, function()
		run("SetHighestZone", 1)
	end)
	button(progress, "+1 rebirth", Theme.Colors.Purple, function()
		run("AddRebirths", 1)
	end)
	button(progress, "+10 rebirths", Theme.Colors.Purple, function()
		run("AddRebirths", 10)
	end)
	button(progress, "Rebirths → 0", Theme.Colors.Red, function()
		run("AddRebirths", -1e9)
	end)
	button(progress, "Max upgrades", Theme.Colors.Purple, function()
		run("MaxUpgrades")
	end)
	button(progress, "Reset upgrades", Theme.Colors.Red, function()
		run("ResetUpgrades")
	end)

	-- Timers
	local timers = section("⏱ Timers")
	button(timers, "Daily reward ready", Theme.Colors.Blue, function()
		run("DailyReady")
	end)
	button(timers, "All gifts ready", Theme.Colors.Blue, function()
		run("GiftsReady")
	end)
	button(timers, "Complete quests", Theme.Colors.Blue, function()
		run("CompleteQuests")
	end)

	-- Passes (session only)
	local passes = section("🎟 Game passes (this session only)")
	local passButtons: { [string]: TextButton } = {}
	for _, pass in Products.GamePasses do
		passButtons[pass.Key] = button(passes, pass.Name, Theme.Colors.Disabled, function()
			run("SetPass", pass.Key, not State.Session.Passes[pass.Key])
		end)
	end
	State.watch({ "Session.Passes" }, function()
		for key, passButton in passButtons do
			local owned = State.Session.Passes[key] == true
			local pass = Products.PassByKey[key]
			passButton.Text = pass.Icon .. " " .. pass.Name .. (if owned then " ✓" else "")
			passButton.BackgroundColor3 = if owned then Theme.Colors.Green else Theme.Colors.Disabled
		end
	end)

	-- Teleport
	local teleport = section("🗺 Teleport")
	for index, zone in Zones.List do
		button(teleport, zone.Icon .. " " .. zone.Name, Theme.Colors.PanelLight, function()
			run("Teleport", index)
		end)
	end

	-- Testing & debug
	local testing = section("🧪 Testing & debug")
	local eggIndex = picker(testing, #Eggs.List, function(index)
		local egg = Eggs.List[index]
		return egg.Name, egg.Color
	end)
	button(testing, "Simulate 10K hatches", Theme.Colors.Purple, function()
		run("SimulateHatches", Eggs.List[eggIndex()].Id, 10000)
	end)
	button(testing, "Simulate 100K hatches", Theme.Colors.Purple, function()
		run("SimulateHatches", Eggs.List[eggIndex()].Id, 100000)
	end)
	button(testing, "Server info", Theme.Colors.Gray, function()
		run("ServerInfo")
	end)
	button(testing, "Save now", Theme.Colors.Gray, function()
		run("SaveNow")
	end)
	button(testing, "⚠️ Reset my data", Theme.Colors.Red, function(self)
		if self.Text ~= "Tap again!" then
			self.Text = "Tap again!"
			task.delay(3, function()
				self.Text = "⚠️ Reset my data"
			end)
			return
		end
		self.Text = "⚠️ Reset my data"
		run("ResetData")
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F2 and State.Session.IsAdmin then
			Windows.toggle(NAME)
		end
	end)
end

return AdminWindow
