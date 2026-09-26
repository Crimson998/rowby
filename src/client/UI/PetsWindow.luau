--[[
	Pet inventory and the Pet Index.

	Copies of the same pet are stacked into one card ("×12") so the inventory stays readable.
	Select a stack to equip/unequip copies, lock it (locked pets are never deleted or used for
	crafting), craft 5 copies into the next tier (Golden → Diamond → Emerald → Void), or delete
	copies. The toolbar has one-click Equip Best, Craft All and Delete Weak.
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
local TOOLBAR_HEIGHT = 84

type Stack = {
	Key: string,
	Id: string,
	Tier: number,
	Power: number,
	Equipped: { string },
	Unequipped: { string },
	-- Unequipped and unlocked: the copies that can be deleted.
	Deletable: { string },
	All: { string },
	LockedCount: number,
}

local mode = "Inventory"
local selectedKey: string? = nil
local dirty = true

local grid: ScrollingFrame
local info: TextLabel
local modeButton: TextButton
local detail: Frame
local detailViewport: ViewportFrame
local detailName: TextLabel
local detailRarity: TextLabel
local detailOwned: TextLabel
local equipButton: TextButton
local unequipButton: TextButton
local lockButton: TextButton
local craftButton: TextButton
local deleteOneButton: TextButton
local deleteAllButton: TextButton
local toolButtons: { GuiObject } = {}

local function rarityColor(petId: string): Color3
	return Config.Rarities[Pets[petId].Rarity].Color
end

local function buildStacks(): { Stack }
	local byKey: { [string]: Stack } = {}
	local list: { Stack } = {}
	for uid, pet in State.Data.Pets do
		local tier = Formula.tier(pet.Tier)
		local key = pet.Id .. ":" .. tier
		local stack = byKey[key]
		if not stack then
			stack = {
				Key = key,
				Id = pet.Id,
				Tier = tier,
				Power = Formula.petPower(pet.Id, tier),
				Equipped = {},
				Unequipped = {},
				Deletable = {},
				All = {},
				LockedCount = 0,
			}
			byKey[key] = stack
			table.insert(list, stack)
		end
		table.insert(stack.All, uid)
		if pet.Equipped then
			table.insert(stack.Equipped, uid)
		else
			table.insert(stack.Unequipped, uid)
			if not pet.Locked then
				table.insert(stack.Deletable, uid)
			end
		end
		if pet.Locked then
			stack.LockedCount += 1
		end
	end
	for _, stack in list do
		table.sort(stack.Deletable)
		table.sort(stack.Unequipped)
	end
	table.sort(list, function(a, b)
		local aEquipped, bEquipped = #a.Equipped > 0, #b.Equipped > 0
		if aEquipped ~= bEquipped then
			return aEquipped
		end
		if a.Power ~= b.Power then
			return a.Power > b.Power
		end
		return a.Key < b.Key
	end)
	return list
end

local function card(order: number, petId: string, tier: number, hidden: boolean): TextButton
	local tierDef = Config.Tiers[tier]
	local button = Util.button({
		LayoutOrder = order,
		Color = if tierDef.Color then tierDef.Color:Lerp(Theme.Colors.PanelLight, 0.55) else Theme.Colors.PanelLight,
		Parent = grid,
	})
	local stroke = button:FindFirstChild("Border") :: UIStroke
	stroke.Color = rarityColor(petId)
	local viewport = Viewport.new({ Size = UDim2.new(1, 0, 0, 74), Parent = button })
	Viewport.show(viewport, PetModels.pet(petId, tier))
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
		Text = if hidden then Pets[petId].Rarity else "+" .. Format.number(Formula.petPower(petId, tier)) .. "x",
		TextColor3 = rarityColor(petId),
		Parent = button,
	})
	if tier > 1 then
		Util.label({
			Size = UDim2.fromOffset(22, 22),
			Position = UDim2.new(1, -24, 0, 0),
			Text = tierDef.Icon,
			Parent = button,
		})
	end
	return button
end

local function selectedStack(stacks: { Stack }): Stack?
	for _, stack in stacks do
		if stack.Key == selectedKey then
			return stack
		end
	end
	return nil
end

-- Buttons that need a second tap within 3 seconds.
local confirmations: { [TextButton]: number } = {}
local function confirmed(button: TextButton, label: string): boolean
	local now = os.clock()
	if now - (confirmations[button] or 0) < 3 then
		confirmations[button] = nil
		return true
	end
	confirmations[button] = now
	button.Text = "Tap again!"
	task.delay(3, function()
		if confirmations[button] == now then
			confirmations[button] = nil
			button.Text = label
		end
	end)
	return false
end

local function refreshDetail(stack: Stack?)
	detail.Visible = mode == "Inventory"
	local buttons = { equipButton, unequipButton, lockButton, craftButton, deleteOneButton, deleteAllButton }
	if not stack then
		detailName.Text = "Select a pet"
		detailRarity.Text = ""
		detailOwned.Text = "Tap a card to manage it."
		detailViewport.Visible = false
		for _, button in buttons do
			button.Visible = false
		end
		return
	end
	for _, button in buttons do
		button.Visible = true
		confirmations[button] = nil
	end
	local def = Pets[stack.Id]
	detailViewport.Visible = true
	local tierDef = Config.Tiers[stack.Tier]
	Viewport.show(detailViewport, PetModels.pet(stack.Id, stack.Tier), 5)
	detailName.Text = (if stack.Tier > 1 then tierDef.Icon .. " " .. tierDef.Name .. " " else "") .. def.Name
	detailRarity.Text = def.Rarity .. "  ·  +" .. Format.number(stack.Power) .. "x each"
	detailRarity.TextColor3 = rarityColor(stack.Id)
	detailOwned.Text =
		string.format("Owned %d  ·  Equipped %d  ·  Locked %d", #stack.All, #stack.Equipped, stack.LockedCount)

	equipButton.Text = "Equip +1"
	equipButton.BackgroundColor3 = if #stack.Unequipped > 0 then Theme.Colors.Green else Theme.Colors.Disabled
	unequipButton.Text = "Unequip -1"
	unequipButton.BackgroundColor3 = if #stack.Equipped > 0 then Theme.Colors.Red else Theme.Colors.Disabled

	local allLocked = stack.LockedCount == #stack.All
	lockButton.Text = if allLocked then "🔓 Unlock" else "🔒 Lock"
	lockButton.BackgroundColor3 = if allLocked then Theme.Colors.Gray else Theme.Colors.Blue

	local unlockedCopies = #stack.All - stack.LockedCount
	local nextTier = Config.Tiers[stack.Tier + 1]
	craftButton.Visible = nextTier ~= nil
	if nextTier then
		craftButton.Text = string.format(
			"%s %s %d/%d",
			nextTier.Icon,
			nextTier.Name,
			math.min(unlockedCopies, Config.Pets.CraftCopies),
			Config.Pets.CraftCopies
		)
		craftButton.BackgroundColor3 = if unlockedCopies >= Config.Pets.CraftCopies
			then Theme.Colors.Gold
			else Theme.Colors.Disabled
	end

	local canDelete = #stack.Deletable > 0
	deleteOneButton.Text = "🗑 Delete 1"
	deleteAllButton.Text = "🗑 All (" .. #stack.Deletable .. ")"
	deleteOneButton.BackgroundColor3 = if canDelete then Theme.Colors.Red else Theme.Colors.Disabled
	deleteAllButton.BackgroundColor3 = if canDelete then Theme.Colors.Red else Theme.Colors.Disabled
end

local function currentStack(): Stack?
	return selectedStack(buildStacks())
end

local function rebuild()
	dirty = false
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local data = State.Data
	for _, button in toolButtons do
		button.Visible = mode == "Inventory"
	end
	if mode == "Inventory" then
		modeButton.Text = "📖 Index"
		local equipped = 0
		for _, pet in data.Pets do
			if pet.Equipped then
				equipped += 1
			end
		end
		local count = Formula.petCount(data)
		local nearlyFull = count >= Config.Pets.Storage * 0.9
		info.Text = string.format(
			"Equipped %d/%d  ·  Storage %d/%d%s",
			equipped,
			Formula.equipSlots(data, State.Session),
			count,
			Config.Pets.Storage,
			if nearlyFull then "  ⚠️" else ""
		)
		info.TextColor3 = if nearlyFull then Theme.Colors.Orange else Theme.Colors.Text

		local stacks = buildStacks()
		if not selectedStack(stacks) then
			selectedKey = nil
		end
		for order, stack in stacks do
			local button = card(order, stack.Id, stack.Tier, false)
			local marks = (if #stack.Equipped > 0 then "✅" else "") .. (if stack.LockedCount > 0 then "🔒" else "")
			if marks ~= "" then
				Util.label({
					Size = UDim2.fromOffset(44, 22),
					Position = UDim2.fromOffset(0, 0),
					Text = marks,
					Parent = button,
				})
			end
			if #stack.All > 1 then
				Util.label({
					AnchorPoint = Vector2.new(1, 0),
					Size = UDim2.fromOffset(46, 22),
					Position = UDim2.new(1, 0, 0, 52),
					Text = "×" .. #stack.All,
					TextXAlignment = Enum.TextXAlignment.Right,
					Parent = button,
				})
			end
			if stack.Key == selectedKey then
				(button:FindFirstChild("Border") :: UIStroke).Thickness = 5
			end
			button.Activated:Connect(function()
				selectedKey = stack.Key
				rebuild()
			end)
		end
		refreshDetail(selectedStack(stacks))
		grid.Size = UDim2.new(1, -DETAIL_WIDTH - 10, 1, -TOOLBAR_HEIGHT)
	else
		modeButton.Text = "🎒 Inventory"
		local order = PetModels.indexOrder()
		local found = 0
		for index, petId in order do
			local discovered = data.Index[petId] == true
			if discovered then
				found += 1
			end
			card(index, petId, 1, not discovered)
		end
		info.Text = string.format("Discovered %d/%d  ·  New pets give 💎!", found, #order)
		info.TextColor3 = Theme.Colors.Text
		grid.Size = UDim2.new(1, 0, 1, -TOOLBAR_HEIGHT)
		refreshDetail(nil)
	end
end

local function toolButton(order: number, text: string, color: Color3, onClick: (TextButton) -> ()): TextButton
	local button: TextButton
	button = Util.button({
		LayoutOrder = order,
		Text = text,
		Size = UDim2.fromOffset(170, 36),
		Color = color,
		Parent = nil,
	}, function()
		onClick(button)
	end)
	table.insert(toolButtons, button)
	return button
end

function PetsWindow.build()
	local body = Windows.create(NAME, "🐾 Pets", Theme.Colors.Orange, Vector2.new(780, 500))

	info = Util.label({
		Size = UDim2.new(1, -170, 0, 32),
		Position = UDim2.fromOffset(0, 2),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = body,
	})
	modeButton = Util.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(150, 36),
		Color = Theme.Colors.Purple,
		Parent = body,
	}, function()
		mode = if mode == "Inventory" then "Index" else "Inventory"
		rebuild()
	end)

	local toolbar = Util.new("Frame", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Parent = body,
	}, { Util.list(Enum.FillDirection.Horizontal, 8) })
	toolButton(1, "⭐ Equip Best", Theme.Colors.Green, function()
		Actions("EquipBest")
	end).Parent = toolbar
	toolButton(2, "✨ Craft All", Theme.Colors.Gold, function()
		Actions("CraftAll")
	end).Parent = toolbar
	toolButton(3, "🗑 Delete Weak", Theme.Colors.Red, function(button)
		if confirmed(button, "🗑 Delete Weak") then
			button.Text = "🗑 Delete Weak"
			Actions("DeleteWeak")
		end
	end).Parent =
		toolbar
	local hint = Util.label({
		LayoutOrder = 4,
		Size = UDim2.fromOffset(200, 36),
		Text = "Delete Weak keeps locked, equipped, crafted & Legendary+",
		TextColor3 = Theme.Colors.SubText,
		TextWrapped = true,
		Parent = toolbar,
	})
	table.insert(toolButtons, hint)

	grid = Util.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, TOOLBAR_HEIGHT),
		Size = UDim2.new(1, -DETAIL_WIDTH - 10, 1, -TOOLBAR_HEIGHT),
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
		Position = UDim2.new(1, 0, 0, TOOLBAR_HEIGHT),
		Size = UDim2.new(0, DETAIL_WIDTH, 1, -TOOLBAR_HEIGHT),
		BackgroundColor3 = Theme.Colors.Panel,
		Parent = body,
	}, { Util.corner(14) })
	detailViewport = Viewport.new({ Size = UDim2.new(1, 0, 0, 100), Parent = detail })
	detailName = Util.label({
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 100),
		Text = "",
		Parent = detail,
	})
	detailRarity = Util.label({
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 126),
		Text = "",
		Parent = detail,
	})
	detailOwned = Util.label({
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 148),
		Text = "",
		TextColor3 = Theme.Colors.SubText,
		Parent = detail,
	})

	local function halfButton(row: number, column: number, onClick: (TextButton) -> ()): TextButton
		local button: TextButton
		button = Util.button({
			Size = UDim2.new(0.5, -14, 0, 36),
			Position = UDim2.new(
				if column == 1 then 0 else 0.5,
				if column == 1 then 10 else 4,
				0,
				170 + (row - 1) * 42
			),
			Parent = detail,
		}, function()
			local stack = currentStack()
			if stack then
				onClick(button)
			end
		end)
		return button
	end

	equipButton = halfButton(1, 1, function()
		local stack = currentStack()
		if stack and #stack.Unequipped > 0 then
			Actions("Equip", stack.Unequipped[1])
		end
	end)
	unequipButton = halfButton(1, 2, function()
		local stack = currentStack()
		if stack and #stack.Equipped > 0 then
			Actions("Unequip", stack.Equipped[1])
		end
	end)
	lockButton = halfButton(2, 1, function()
		local stack = currentStack()
		if stack then
			Actions("SetLocked", stack.All, stack.LockedCount < #stack.All)
		end
	end)
	craftButton = halfButton(2, 2, function()
		local stack = currentStack()
		if stack then
			Actions("Craft", stack.Id, stack.Tier)
		end
	end)
	deleteOneButton = halfButton(3, 1, function()
		local stack = currentStack()
		if stack and #stack.Deletable > 0 then
			Actions("DeletePets", { stack.Deletable[1] })
		end
	end)
	deleteAllButton = halfButton(3, 2, function(button)
		local stack = currentStack()
		if stack and #stack.Deletable > 0 and confirmed(button, "🗑 All (" .. #stack.Deletable .. ")") then
			Actions("DeletePets", stack.Deletable)
		end
	end)
	Util.label({
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.new(0, 8, 1, -4),
		Text = "Locked pets are never deleted or used for crafting.",
		TextColor3 = Theme.Colors.SubText,
		TextWrapped = true,
		Parent = detail,
	})

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
