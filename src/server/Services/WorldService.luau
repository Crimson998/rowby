--[[
	Builds the map at server start (see MapBuilder) and runs the clover spawner. Other services
	hook into the gate and egg prompts exposed here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Eggs = require(Shared.Eggs)
local Formula = require(Shared.Formula)
local Net = require(Shared.Net)
local Zones = require(Shared.Zones)

local MapBuilder = require(script.Parent.Parent.MapBuilder)
local DataService = require(script.Parent.DataService)

local WorldService = {}

-- [zoneIndex] = unlock prompts along that zone's gate
WorldService.Gates = {} :: { [number]: { ProximityPrompt } }
-- [eggId] = hatch prompts and where the egg stands
WorldService.EggPrompts = {} :: { [string]: { Single: ProximityPrompt, Triple: ProximityPrompt, Position: Vector3 } }
-- [boardName] = row labels, filled by LeaderboardService
WorldService.Boards = {} :: { [string]: { TextLabel } }

local LENGTH = Zones.Layout.Length
local rgb = Color3.fromRGB
local eggPosition = MapBuilder.eggPosition

local worldFolder: Folder
local orbFolder: Folder
type Clover = { Kind: string, Position: Vector3 }
local orbs: { [number]: { [Model]: Clover } } = {}
local orbRng = Random.new()

-- A standing clover: bright heart-shaped leaves, a darker centre and a stem, all anchored in one
-- Model (no welds). Clients bob and spin the whole model with PivotTo. Lucky clovers are golden
-- with four leaves and sparkles.
local CLOVER_LEAF = rgb(45, 235, 95)
local CLOVER_STEM = rgb(30, 150, 60)
local LUCKY_LEAF = rgb(255, 205, 40)
local LUCKY_STEM = rgb(200, 140, 20)

local function cloverPart(
	model: Model,
	origin: CFrame,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	ellipsoid: boolean
): Part
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = origin * offset
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	if ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Parent = model
	return part
end

local function buildClover(lucky: boolean, origin: CFrame): Model
	local scale = if lucky then 1.35 else 1
	local leafColor = if lucky then LUCKY_LEAF else CLOVER_LEAF
	local stemColor = if lucky then LUCKY_STEM else CLOVER_STEM
	local model = Instance.new("Model")
	model.Name = if lucky then "LuckyClover" else "Clover"

	-- Each leaf is two overlapping ovals, making a heart shape pointing at the centre.
	local leaves = if lucky then 4 else 3
	for index = 1, leaves do
		local direction = CFrame.Angles(0, 0, math.rad(90 + (index - 1) * 360 / leaves))
		for side = -1, 1, 2 do
			cloverPart(
				model,
				origin,
				Vector3.new(0.62, 0.62, 0.16) * scale,
				direction * CFrame.new(0.45 * scale, side * 0.17 * scale, 0),
				leafColor,
				Enum.Material.Neon,
				true
			)
		end
	end
	local centre = cloverPart(
		model,
		origin,
		Vector3.new(0.3, 0.3, 0.2) * scale,
		CFrame.new(),
		stemColor,
		Enum.Material.SmoothPlastic,
		true
	)
	cloverPart(
		model,
		origin,
		Vector3.new(0.12, 0.9, 0.12) * scale,
		CFrame.new(0.12 * scale, -0.6 * scale, 0) * CFrame.Angles(0, 0, math.rad(-12)),
		stemColor,
		Enum.Material.SmoothPlastic,
		false
	)
	if lucky then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = rgb(255, 235, 120)
		sparkles.Parent = centre
	end
	model.WorldPivot = origin
	-- Lets clients wait until every part has arrived before animating.
	model:SetAttribute("PartCount", #model:GetChildren())
	return model
end

local function spawnOrb(zoneIndex: number)
	local zoneStart = (zoneIndex - 1) * LENGTH
	local egg = eggPosition(zoneIndex)
	local position = Vector3.zero
	for _ = 1, 10 do
		position =
			Vector3.new(orbRng:NextNumber(-90, 90), 1.6, orbRng:NextNumber(zoneStart + 10, zoneStart + LENGTH - 10))
		if (position - egg).Magnitude > 12 then
			break
		end
	end
	local lucky = orbRng:NextNumber() < Config.Orbs.LuckyChance
	local orb = buildClover(lucky, CFrame.new(position))

	orb:SetAttribute("Zone", zoneIndex)
	orb.Parent = orbFolder
	orbs[zoneIndex][orb] = { Kind = if lucky then "LuckyClover" else "Clover", Position = position }
end

-- Clovers give Luck XP (never coins; coins come only from tapping).
local function collectOrb(profile, orb: Model, clover: Clover, zoneIndex: number)
	orbs[zoneIndex][orb] = nil
	local position = clover.Position
	local kind = clover.Kind
	orb:Destroy()

	local data = profile.Data
	local amount = Formula.cloverValue(zoneIndex, kind == "LuckyClover")
	local levelBefore = Formula.luckLevel(data.LuckXP)
	data.LuckXP += amount
	data.Stats.OrbsCollected += 1
	DataService.change(profile, "LuckXP", "Stats")
	Net.event("OrbCollected"):FireClient(profile.Player, position, kind, amount)

	local levelAfter = Formula.luckLevel(data.LuckXP)
	if levelAfter > levelBefore then
		Net.event("Effect"):FireClient(profile.Player, "LuckLevel", levelAfter)
	end

	task.delay(Config.Orbs.RespawnSeconds, spawnOrb, zoneIndex)
end

function WorldService.eggPosition(eggId: string): Vector3?
	local prompts = WorldService.EggPrompts[eggId]
	return prompts and prompts.Position
end

-- Flags custom models whose names don't match a pet or egg id (usually a typo).
local function checkCustomModels()
	local Pets = require(Shared.Pets)
	local folders = { PetModels = Pets, EggModels = Eggs.ById }
	for folderName, known in folders do
		local folder = ReplicatedStorage:FindFirstChild(folderName)
		if not folder then
			continue
		end
		for _, child in folder:GetChildren() do
			local id = child.Name
			for _, tier in Config.Tiers do
				id = string.gsub(id, "_" .. tier.Name .. "$", "")
			end
			if not (known :: any)[id] then
				warn(
					string.format(
						"[CustomModels] %s.%s doesn't match any id, so it won't be used",
						folderName,
						child.Name
					)
				)
			end
		end
	end
end

function WorldService.Init()
	checkCustomModels()
	-- An edit-mode preview saved into the place by accident must not linger in the real game.
	local leftoverPreview = workspace:FindFirstChild(MapBuilder.PreviewName)
	if leftoverPreview then
		leftoverPreview:Destroy()
	end

	worldFolder = Instance.new("Folder")
	worldFolder.Name = "World"
	local built = MapBuilder.build(worldFolder, false)
	WorldService.Gates = built.Gates
	WorldService.EggPrompts = built.EggPrompts
	WorldService.Boards = built.Boards
	worldFolder.Parent = workspace
	MapBuilder.setupLighting()

	orbFolder = Instance.new("Folder")
	orbFolder.Name = "Orbs"
	orbFolder.Parent = worldFolder
	for index in Zones.List do
		orbs[index] = {}
		for _ = 1, Config.Orbs.PerZone do
			spawnOrb(index)
		end
	end
end

function WorldService.Start()
	task.spawn(function()
		while true do
			task.wait(0.15)
			for player, profile in DataService.all() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not root then
					continue
				end
				local position = root.Position
				local zoneIndex = Zones.indexAt(position.Z)
				if zoneIndex > profile.Data.HighestZone then
					continue
				end
				local radius = Formula.magnetRadius(profile.Data)
				for orb, clover in orbs[zoneIndex] do
					if (clover.Position - position).Magnitude <= radius then
						collectOrb(profile, orb, clover, zoneIndex)
					end
				end
			end
		end
	end)
end

return WorldService
