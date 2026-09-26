--[[
	Local world presentation:
	- odds boards over every egg (computed with *your* luck, so they're always exact)
	- gates vanish for areas you own, and only the next area's gate can be bought
	- lighting and atmosphere blend as you walk between areas
	- clovers bob and spin; collected clovers fly into you with a "+🍀 Luck XP" popup
	- a guide beam points new players to the first egg and anyone to a gate they can afford
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Eggs = require(Shared.Eggs)
local Format = require(Shared.Format)
local Formula = require(Shared.Formula)
local Pets = require(Shared.Pets)
local Zones = require(Shared.Zones)

local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)
local Util = require(script.Parent.Parent.UI.Util)
local Notifications = require(script.Parent.Parent.UI.Notifications)

local World = {}

local player = Players.LocalPlayer
local eggBoards: { [string]: BillboardGui } = {}
local lastLuck = -1
local currentZone = 0

-- Egg odds boards ---------------------------------------------------------------------------

local refreshEggBoards: () -> ()

local function buildEggBoard(stand: Instance)
	local eggId = stand:GetAttribute("EggId")
	local egg = Eggs.ById[eggId]
	local eggModel = stand:WaitForChild("Egg", 30) :: Model?
	if not egg or not eggModel or eggBoards[eggId] then
		return
	end
	while not eggModel.PrimaryPart do
		eggModel:GetPropertyChangedSignal("PrimaryPart"):Wait()
	end
	local rowHeight = 24
	local board = Util.new("BillboardGui", {
		Name = "Odds",
		Adornee = eggModel.PrimaryPart,
		Size = UDim2.fromOffset(250, 84 + #egg.Pets * rowHeight),
		StudsOffset = Vector3.new(0, 9, 0),
		MaxDistance = 80,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local frame = Util.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.15,
		Parent = board,
	}, { Util.corner(14), Util.stroke(egg.Color, 3) })
	Util.label({
		Name = "Title",
		Size = UDim2.new(1, -12, 0, 30),
		Position = UDim2.fromOffset(6, 4),
		Text = egg.Name,
		Parent = frame,
	})
	Util.label({
		Name = "Price",
		Size = UDim2.new(1, -12, 0, 22),
		Position = UDim2.fromOffset(6, 34),
		Text = "🪙 " .. Format.number(egg.Price),
		TextColor3 = Theme.Colors.Coins,
		Parent = frame,
	})
	for index, entry in egg.Pets do
		local pet = Pets[entry.Id]
		local y = 58 + (index - 1) * rowHeight
		Util.label({
			Size = UDim2.new(0.62, -8, 0, rowHeight - 4),
			Position = UDim2.fromOffset(8, y),
			Text = pet.Name,
			TextColor3 = Config.Rarities[pet.Rarity].Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		Util.label({
			Name = "Chance" .. index,
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.new(0.38, -8, 0, rowHeight - 4),
			Position = UDim2.new(1, -8, 0, y),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = frame,
		})
	end
	Util.label({
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(1, -12, 0, 20),
		Position = UDim2.new(0, 6, 1, -3),
		Text = "",
		TextColor3 = Theme.Colors.Green,
		Parent = frame,
	})
	eggBoards[eggId] = board
	lastLuck = -1
	refreshEggBoards()
end

function refreshEggBoards()
	local luck = Formula.luck(State.Data, State.Session)
	if luck == lastLuck then
		return
	end
	lastLuck = luck
	for eggId, board in eggBoards do
		local egg = Eggs.ById[eggId]
		local frame = board:FindFirstChildOfClass("Frame") :: Frame
		local odds = Formula.eggOdds(eggId, luck)
		for index, entry in odds do
			local label = frame:FindFirstChild("Chance" .. index) :: TextLabel?
			if label then
				label.Text = Format.chance(entry.Chance)
			end
		end
		local footer = frame:FindFirstChild("Footer") :: TextLabel
		if egg.Zone > State.Data.HighestZone then
			footer.Text = "🔒 Unlock " .. Zones.List[egg.Zone].Name
			footer.TextColor3 = Theme.Colors.Red
		else
			footer.Text = if luck > 1 then "🍀 Your luck: " .. Format.multiplier(luck) else "E to hatch · R for x3"
			footer.TextColor3 = Theme.Colors.Green
		end
	end
end

-- Gates ------------------------------------------------------------------------------------

local function refreshGates()
	local highest = State.Data.HighestZone
	for _, gate in CollectionService:GetTagged("ZoneGate") do
		if not gate:IsA("BasePart") then
			continue
		end
		local zoneIndex = gate:GetAttribute("Zone") :: number
		local unlocked = zoneIndex <= highest
		gate.CanCollide = not unlocked
		gate.Transparency = if unlocked then 1 else 0
		for _, child in gate:GetDescendants() do
			if child:IsA("SurfaceGui") then
				child.Enabled = not unlocked
			elseif child:IsA("ProximityPrompt") then
				child.Enabled = zoneIndex == highest + 1
			end
		end
	end
end

-- Area lighting ----------------------------------------------------------------------------

local function applyZone(index: number, instant: boolean)
	local zone = Zones.List[index]
	local seconds = if instant then 0 else 2
	Util.tween(Lighting, seconds, { ClockTime = zone.ClockTime }, Enum.EasingStyle.Sine)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		Util.tween(atmosphere, seconds, {
			Color = zone.AtmosphereColor,
			Decay = zone.AtmosphereDecay,
			Density = zone.AtmosphereDensity,
		}, Enum.EasingStyle.Sine)
	end
	if not instant then
		Notifications.banner(zone.Icon .. " " .. zone.Name, zone.Accent, 2.2)
	end
end

local function watchZone()
	while true do
		task.wait(0.4)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local index = Zones.indexAt(root.Position.Z)
			if index ~= currentZone then
				applyZone(index, currentZone == 0)
				currentZone = index
			end
		end
	end
end

-- Orbs -------------------------------------------------------------------------------------

local orbBases: { [Model]: { CFrame: CFrame, Phase: number } } = {}

-- Clovers are Models of anchored parts; wait until every part has arrived, then remember
-- where the clover stands so it can bob and spin around that spot.
local function trackOrb(orb: Instance)
	if not orb:IsA("Model") then
		return
	end
	task.spawn(function()
		local expected = orb:GetAttribute("PartCount")
		local deadline = os.clock() + 5
		while orb.Parent and type(expected) == "number" and #orb:GetChildren() < expected and os.clock() < deadline do
			task.wait()
		end
		if orb.Parent then
			orbBases[orb] = { CFrame = orb:GetPivot(), Phase = math.random() * math.pi * 2 }
		end
	end)
	orb.Destroying:Connect(function()
		orbBases[orb] = nil
	end)
end

local function animateOrbs()
	local now = os.clock()
	for orb, info in orbBases do
		orb:PivotTo(
			info.CFrame * CFrame.new(0, math.sin(now * 2.5 + info.Phase) * 0.35, 0) * CFrame.Angles(0, now * 2, 0)
		)
	end
end

function World.orbCollected(position: Vector3, kind: string, amount: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local lucky = kind == "LuckyClover"
	local color = if lucky then Theme.Colors.Gold else Theme.Colors.Luck

	local spark = Instance.new("Part")
	spark.Shape = Enum.PartType.Ball
	spark.Size = Vector3.one * 1.2
	spark.Material = Enum.Material.Neon
	spark.Color = color
	spark.Anchored = true
	spark.CanCollide = false
	spark.CanQuery = false
	spark.CanTouch = false
	spark.CFrame = CFrame.new(position)
	spark.Parent = workspace
	if root then
		Util.tween(
			spark,
			0.25,
			{ CFrame = root.CFrame, Size = Vector3.one * 0.2 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
	end
	task.delay(0.26, function()
		spark:Destroy()
	end)

	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.1
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace
	local popup = Util.new("BillboardGui", {
		Size = UDim2.fromOffset(160, 40),
		StudsOffset = Vector3.new(0, 2, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Parent = anchor,
	})
	local text = Util.label({
		Size = UDim2.fromScale(1, 1),
		Text = "+🍀 " .. Format.number(amount) .. (if lucky then " LUCKY!" else ""),
		TextColor3 = color,
		Parent = popup,
	})
	Util.tween(popup, 0.8, { StudsOffset = Vector3.new(0, 5, 0) })
	Util.tween(text, 0.8, { TextTransparency = 1 })
	task.delay(0.8, function()
		anchor:Destroy()
	end)
	Sound.play("Coin", if lucky then 1.5 else 1.2 + math.random() * 0.2, 0.3)
end

-- Guide beam -------------------------------------------------------------------------------

local beam: Beam
local beamTarget: Attachment
local beamSource: Attachment?

local function guideTarget(): (Vector3?, Color3?)
	local data = State.Data
	if data.Stats.EggsHatched == 0 then
		local egg = Eggs.List[1]
		local stand = nil
		for _, candidate in CollectionService:GetTagged("EggStand") do
			if candidate:GetAttribute("EggId") == egg.Id then
				stand = candidate
			end
		end
		local eggModel = stand and stand:FindFirstChild("Egg") :: Model?
		if eggModel and eggModel.PrimaryPart and data.Coins >= egg.Price then
			return eggModel.PrimaryPart.Position, Theme.Colors.Green
		end
		return nil, nil
	end
	local nextIndex = data.HighestZone + 1
	local zone = Zones.List[nextIndex]
	if zone and data.Coins >= zone.UnlockCost then
		return Vector3.new(0, 3, (nextIndex - 1) * Zones.Layout.Length - 2), zone.Accent
	end
	return nil, nil
end

local function updateBeam()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and (not beamSource or beamSource.Parent ~= root) then
		local source = Instance.new("Attachment")
		source.Name = "GuideSource"
		source.Position = Vector3.new(0, -2, 0)
		source.Parent = root
		beamSource = source
		beam.Attachment0 = source
	end
	local position, color = guideTarget()
	if position and color and root then
		beamTarget.WorldPosition = position
		beam.Color = ColorSequence.new(color)
		beam.Enabled = (root.Position - position).Magnitude > 12
	else
		beam.Enabled = false
	end
end

local function buildBeam()
	local anchor = Instance.new("Part")
	anchor.Name = "GuideTarget"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.1
	anchor.Parent = workspace
	beamTarget = Instance.new("Attachment")
	beamTarget.Parent = anchor
	beam = Util.new("Beam", {
		Attachment1 = beamTarget,
		Width0 = 1.4,
		Width1 = 1.4,
		FaceCamera = true,
		LightEmission = 1,
		Segments = 24,
		CurveSize0 = 6,
		CurveSize1 = -6,
		Transparency = NumberSequence.new(0.35),
		Enabled = false,
		Parent = anchor,
	})
end

-- Effects from the server --------------------------------------------------------------------

function World.effect(name: string, ...: any)
	local args = { ... }
	if name == "LuckLevel" then
		local level = args[1]
		Notifications.banner(
			"🍀 Luck Level " .. level .. "!  Luck " .. Format.multiplier(Formula.luck(State.Data, State.Session)),
			Theme.Colors.Luck,
			2.5
		)
		Sound.play("Reveal", 1.4, 0.6)
	elseif name == "Rebirth" then
		local rebirths, gems = args[1], args[2]
		Notifications.banner(
			"🔁 REBIRTH! Coins "
				.. Format.multiplier(Formula.rebirthMultiplier(rebirths))
				.. " forever  +💎 "
				.. gems,
			Theme.Colors.Rebirth,
			3.5
		)
		Sound.play("Reveal", 1.1, 0.8)
	elseif name == "ZoneUnlocked" then
		local zone = Zones.List[args[1]]
		if zone then
			Notifications.banner("🔓 " .. zone.Icon .. " " .. zone.Name .. " unlocked!", zone.Accent, 3)
			Sound.play("Reveal", 1.2, 0.8)
		end
	end
end

function World.start()
	for _, stand in CollectionService:GetTagged("EggStand") do
		task.spawn(buildEggBoard, stand)
	end
	CollectionService:GetInstanceAddedSignal("EggStand"):Connect(buildEggBoard)
	CollectionService:GetInstanceAddedSignal("ZoneGate"):Connect(refreshGates)
	State.watch({ "Upgrades", "Boosts", "HighestZone", "LuckXP", "Session.Passes" }, refreshEggBoards)
	State.watch({ "HighestZone" }, function()
		lastLuck = -1
		refreshEggBoards()
		refreshGates()
	end)

	local worldFolder = workspace:WaitForChild("World")
	local orbFolder = worldFolder:WaitForChild("Orbs")
	for _, orb in orbFolder:GetChildren() do
		trackOrb(orb)
	end
	orbFolder.ChildAdded:Connect(trackOrb)

	buildBeam()
	task.spawn(watchZone)
	task.spawn(function()
		while true do
			task.wait(0.5)
			updateBeam()
		end
	end)

	local eggSpin = 0
	RunService.RenderStepped:Connect(function(dt)
		animateOrbs()
		eggSpin += dt * 0.6
		for _, stand in CollectionService:GetTagged("EggStand") do
			local eggModel = stand:FindFirstChild("Egg") :: Model?
			local shell = eggModel and eggModel.PrimaryPart
			if eggModel and shell then
				local base = eggModel:GetAttribute("BaseCFrame") :: CFrame?
				if not base then
					base = eggModel:GetPivot()
					eggModel:SetAttribute("BaseCFrame", base)
				end
				eggModel:PivotTo(
					(base :: CFrame) * CFrame.new(0, math.sin(eggSpin * 2) * 0.4, 0) * CFrame.Angles(0, eggSpin, 0)
				)
			end
		end
	end)
end

return World
