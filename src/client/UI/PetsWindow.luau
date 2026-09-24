--[[
	Pet inventory (equip, golden crafting, delete) and the Pet Index collection book.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Formula = require(Shared.Formula)
local Pets = require(Shared.Pets)

local Actions = require(script.Parent.Parent.Actions)
local PetModels = require(script.Parent.Parent.PetModels)
local State = require(script.Parent.Parent.State)
local Viewport = require(script.Parent.Parent.Viewport)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Windows = require(script.Parent.Windows)

local PetsWindow = {}

local NAME = "Pets"
local DETAIL_WIDTH = 220

local mode = "Inventory"
local selectedUid: string? = nil
local dirty = true

local grid: ScrollingFrame
local info: TextLabel
local modeButton: TextButton
local detail: Frame
local detailViewport: ViewportFrame
local detailName: TextLabel
local detailRarity: TextLabel
local detailPower: TextLabel
local equipButton: TextButton
local goldenButton: TextButton
local deleteButton: TextButton
local confirmDelete = 0

local function rarityColor(petId: string): Color3
	return Config.Rarities[Pets[petId].Rarity].Color
end

local function sortedInventory(): { { Uid: string, Pet: any, Power: number } }
	local list = {}
	for uid, pet in State.Data.Pets do
		table.insert(list, { Uid = uid, Pet = pet, Power = Formula.petPower(pet.Id, pet.Golden) })
	end
	table.sort(list, function(a, b)
		if a.Pet.Equipped ~= b.Pet.Equipped then
			return a.Pet.Equipped
		end
		if a.Power ~= b.Power then
			return a.Power > b.Power
		end
		return a.Uid < b.Uid
	end)
	return list
end

local function card(order: number, petId: string, golden: boolean, hidden: boolean): TextButton
	local button = Util.button({
		LayoutOrder = order,
		Color = if golden then Color3.fromRGB(120, 95, 30) else Theme.Colors.PanelLight,
		Parent = grid,
	})
	local stroke = button:FindFirstChild("Border") :: UIStroke
	stroke.Color = rarityColor(petId)
	local viewport = Viewport.new({ Size = UDim2.new(1, 0, 0, 74), Parent = button })
	Viewport.show(viewport, PetModels.pet(petId, golden))
	if hidden then
		viewport.ImageColor3 = Color3.new(0, 0, 0)
	end
	Util.label({
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 76),
		Text = if hidden then "???" else Pets[petId].Name,
		Parent = button,
	})
	Util.label({
		Name = "Power",
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 94),
		Text = if hidden then Pets[petId].Rarity else "+" .. Format.number(Formula.petPower(petId, golden)) .. "x",
		TextColor3 = rarityColor(petId),
		Parent = button,
	})
	if golden then
		Util.label({
			Size = UDim2.fromOffset(22, 22),
			Position = UDim2.new(1, -24, 0, 0),
			Text = "⭐",
			Parent = button,
		})
	end
	return button
end

local function refreshDetail()
	local pet = selectedUid and State.Data.Pets[selectedUid]
	detail.Visible = mode == "Inventory"
	if not pet then
		detailName.Text = "Select a pet"
		detailRarity.Text = ""
		detailPower.Text = ""
		detailViewport.Visible = false
		equipButton.Visible = false
		goldenButton.Visible = false
		deleteButton.Visible = false
		return
	end
	local def = Pets[pet.Id]
	detailViewport.Visible = true
	Viewport.show(detailViewport, PetModels.pet(pet.Id, pet.Golden), 5)
	detailName.Text = (if pet.Golden then "Golden " else "") .. def.Name
	detailRarity.Text = def.Rarity
	detailRarity.TextColor3 = rarityColor(pet.Id)
	detailPower.Text = "+" .. Format.number(Formula.petPower(pet.Id, pet.Golden)) .. "x coins"

	equipButton.Visible = true
	equipButton.Text = if pet.Equipped then "Unequip" else "Equip"
	equipButton.BackgroundColor3 = if pet.Equipped then Theme.Colors.Red else Theme.Colors.Green

	local copies = 0
	for _, other in State.Data.Pets do
		if other.Id == pet.Id and not other.Golden then
			copies += 1
		end
	end
	goldenButton.Visible = not pet.Golden
	goldenButton.Text =
		string.format("✨ Make Golden (%d/%d)", math.min(copies, Config.Pets.GoldenCopies), Config.Pets.GoldenCopies)
	goldenButton.BackgroundColor3 = if copies >= Config.Pets.GoldenCopies
		then Theme.Colors.Gold
		else Theme.Colors.Disabled

	deleteButton.Visible = true
	deleteButton.Text = "🗑 Delete"
	confirmDelete = 0
end

local function rebuild()
	dirty = false
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local data = State.Data
	if mode == "Inventory" then
		modeButton.Text = "📖 Index"
		local equipped = 0
		for _, pet in data.Pets do
			if pet.Equipped then
				equipped += 1
			end
		end
		info.Text = string.format(
			"Equipped %d/%d  ·  Storage %d/%d",
			equipped,
			Formula.equipSlots(data, State.Session),
			Formula.petCount(data),
			Config.Pets.Storage
		)
		if selectedUid and not data.Pets[selectedUid] then
			selectedUid = nil
		end
		for order, entry in sortedInventory() do
			local button = card(order, entry.Pet.Id, entry.Pet.Golden, false)
			if entry.Pet.Equipped then
				Util.label({
					Size = UDim2.fromOffset(22, 22),
					Position = UDim2.fromOffset(2, 0),
					Text = "✅",
					Parent = button,
				})
			end
			if entry.Uid == selectedUid then
				(button:FindFirstChild("Border") :: UIStroke).Thickness = 5
			end
			button.Activated:Connect(function()
				selectedUid = entry.Uid
				rebuild()
			end)
		end
		grid.Size = UDim2.new(1, -DETAIL_WIDTH - 10, 1, -50)
	else
		modeButton.Text = "🎒 Inventory"
		local order = PetModels.indexOrder()
		local found = 0
		for index, petId in order do
			local discovered = data.Index[petId] == true
			if discovered then
				found += 1
			end
			card(index, petId, false, not discovered)
		end
		info.Text = string.format("Discovered %d/%d  ·  New pets give 💎!", found, #order)
		grid.Size = UDim2.new(1, 0, 1, -50)
	end
	refreshDetail()
end

function PetsWindow.build()
	local body = Windows.create(NAME, "🐾 Pets", Theme.Colors.Orange, Vector2.new(740, 480))

	info = Util.label({
		Size = UDim2.new(0.5, 0, 0, 30),
		Position = UDim2.fromOffset(0, 4),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = body,
	})
	modeButton = Util.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -300, 0, 0),
		Size = UDim2.fromOffset(130, 38),
		Color = Theme.Colors.Purple,
		Parent = body,
	}, function()
		mode = if mode == "Inventory" then "Index" else "Inventory"
		rebuild()
	end)
	Util.button({
		Text = "⭐ Equip Best",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -150, 0, 0),
		Size = UDim2.fromOffset(140, 38),
		Color = Theme.Colors.Green,
		Parent = body,
	}, function()
		Actions("EquipBest")
	end)
	local clearConfirm = 0
	local clearButton: TextButton
	clearButton = Util.button({
		Text = "🗑 Clear Commons",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(140, 38),
		Color = Theme.Colors.Red,
		Parent = body,
	}, function()
		if os.clock() - clearConfirm > 3 then
			clearConfirm = os.clock()
			clearButton.Text = "Tap to confirm"
			task.delay(3, function()
				clearButton.Text = "🗑 Clear Commons"
			end)
			return
		end
		clearConfirm = 0
		clearButton.Text = "🗑 Clear Commons"
		local uids = {}
		for uid, pet in State.Data.Pets do
			if not pet.Equipped and not pet.Golden and Pets[pet.Id].Rarity == "Common" then
				table.insert(uids, uid)
			end
		end
		if #uids > 0 then
			Actions("DeletePets", uids)
		end
	end)

	grid = Util.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, -DETAIL_WIDTH - 10, 1, -50),
		BackgroundColor3 = Theme.Colors.Panel,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	}, {
		Util.corner(14),
		Util.padding(10),
		Util.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(96, 114),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	detail = Util.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 48),
		Size = UDim2.new(0, DETAIL_WIDTH, 1, -50),
		BackgroundColor3 = Theme.Colors.Panel,
		Parent = body,
	}, { Util.corner(14) })
	detailViewport = Viewport.new({ Size = UDim2.new(1, 0, 0, 140), Parent = detail })
	detailName =
		Util.label({ Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 140), Text = "", Parent = detail })
	detailRarity =
		Util.label({ Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 168), Text = "", Parent = detail })
	detailPower = Util.label({
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(8, 190),
		Text = "",
		TextColor3 = Theme.Colors.Coins,
		Parent = detail,
	})

	equipButton = Util.button(
		{ Size = UDim2.new(1, -20, 0, 38), Position = UDim2.fromOffset(10, 220), Parent = detail },
		function()
			local pet = selectedUid and State.Data.Pets[selectedUid]
			if pet then
				Actions(if pet.Equipped then "Unequip" else "Equip", selectedUid)
			end
		end
	)
	goldenButton = Util.button({
		Size = UDim2.new(1, -20, 0, 38),
		Position = UDim2.fromOffset(10, 264),
		Color = Theme.Colors.Gold,
		Parent = detail,
	}, function()
		local pet = selectedUid and State.Data.Pets[selectedUid]
		if pet then
			Actions("MakeGolden", pet.Id)
		end
	end)
	deleteButton = Util.button({
		Size = UDim2.new(1, -20, 0, 38),
		Position = UDim2.fromOffset(10, 308),
		Color = Theme.Colors.Red,
		Parent = detail,
	}, function()
		if not selectedUid then
			return
		end
		if os.clock() - confirmDelete > 3 then
			confirmDelete = os.clock()
			deleteButton.Text = "Tap to confirm"
			return
		end
		Actions("DeletePets", { selectedUid })
		selectedUid = nil
	end)

	State.watch({ "Pets", "Index", "Upgrades", "Session.Passes" }, function()
		dirty = true
		if Windows.isOpen(NAME) then
			rebuild()
		end
	end)
	Windows.onOpen(NAME, function()
		if dirty then
			rebuild()
		end
	end)
end

return PetsWindow
