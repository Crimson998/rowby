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
local textLabel = MapBuilder.textLabel

local worldFolder: Folder
local orbFolder: Folder
local orbs: { [number]: { [BasePart]: string } } = {}
local orbRng = Random.new()

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
	local orb = Instance.new("Part")
	orb.Name = if lucky then "LuckyClover" else "Clover"
	orb.Shape = Enum.PartType.Ball
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CanTouch = false
	orb.CastShadow = false
	orb.Material = Enum.Material.Neon
	orb.Size = Vector3.one * (if lucky then 1.4 else 1)
	orb.Color = if lucky then rgb(255, 215, 60) else rgb(60, 220, 90)
	orb.Transparency = 0.3
	orb.CFrame = CFrame.new(position)

	local icon = Instance.new("BillboardGui")
	icon.Size = UDim2.fromScale(if lucky then 4 else 2.8, if lucky then 4 else 2.8)
	icon.MaxDistance = 120
	icon.LightInfluence = 0
	icon.Parent = orb
	textLabel({ Size = UDim2.fromScale(1, 1), Text = "🍀", TextStrokeTransparency = 1, Parent = icon })
	if lucky then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = rgb(255, 230, 90)
		sparkles.Parent = orb
	end

	orb:SetAttribute("Zone", zoneIndex)
	orb.Parent = orbFolder
	orbs[zoneIndex][orb] = if lucky then "LuckyClover" else "Clover"
end

-- Clovers give Luck XP (never coins; coins come only from tapping).
local function collectOrb(profile, orb: BasePart, kind: string, zoneIndex: number)
	orbs[zoneIndex][orb] = nil
	local position = orb.Position
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
			local id = string.gsub(child.Name, "_Golden$", "")
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
				for orb, kind in orbs[zoneIndex] do
					if (orb.Position - position).Magnitude <= radius then
						collectOrb(profile, orb, kind, zoneIndex)
					end
				end
			end
		end
	end)
end

return WorldService
