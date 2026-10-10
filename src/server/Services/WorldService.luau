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

-- Clovers give Luck XP (never coins; coins come only from tapping). Grabbing them in quick
-- succession builds a streak that multiplies the XP, up to Config.Orbs.StreakMaxMultiplier; a
-- gap longer than Config.Orbs.StreakWindowSeconds resets it.
local function collectOrb(profile, orb: Model, clover: Clover, zoneIndex: number)
	orbs[zoneIndex][orb] = nil
	local position = clover.Position
	local kind = clover.Kind
	orb:Destroy()

	local session = profile.Session
	local now = os.clock()
	session.CloverStreak = if now - (session.LastCloverAt or 0) <= Formula.streakWindow(profile.Data)
		then (session.CloverStreak or 0) + 1
		else 0
	session.LastCloverAt = now

	local data = profile.Data
	local base = Formula.cloverValue(zoneIndex, kind == "LuckyClover")
	-- Random rounding, so a streak step worth +0.3 XP pays 1 XP about 30% of the time.
	local scaled = base * Formula.cloverStreakMultiplier(session.CloverStreak)
	local amount = math.floor(scaled) + (if orbRng:NextNumber() < scaled % 1 then 1 else 0)
	-- At the Luck cap clovers stop paying (progress toward the next level stops at 1 XP short),
	-- which is the cue to rebirth.
	local cap = Formula.luckCap(data.Rebirths)
	local room = math.max(Formula.luckXPForLevel(cap + 1) - 1 - data.LuckXP, 0)
	amount = math.min(amount, room)
	local levelBefore = Formula.luckLevelOf(data)
	data.LuckXP += amount
	data.Stats.OrbsCollected += 1
	DataService.change(profile, "LuckXP", "Stats")
	Net.event("OrbCollected"):FireClient(profile.Player, position, kind, amount)

	local levelAfter = Formula.luckLevelOf(data)
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

				-- Auto Collect perk: every sweep grabs the nearest clovers wherever they are.
				local sweeps = Formula.autoCollectCount(profile.Data)
				local sinceSweep = os.clock() - (profile.Session.LastAutoCollectAt or 0)
				if sweeps > 0 and sinceSweep >= Config.Orbs.AutoCollectSeconds then
					profile.Session.LastAutoCollectAt = os.clock()
					for _ = 1, sweeps do
						local nearest, nearestClover, nearestDistance = nil, nil, math.huge
						for orb, clover in orbs[zoneIndex] do
							local distance = (clover.Position - position).Magnitude
							if distance < nearestDistance then
								nearest, nearestClover, nearestDistance = orb, clover, distance
							end
						end
						if nearest and nearestClover then
							collectOrb(profile, nearest, nearestClover, zoneIndex)
						end
					end
				end
			end
		end
	end)
end

return WorldService
