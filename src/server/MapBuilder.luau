--[[
	Builds the map: areas, decorations, spawn plaza, leaderboards, gates and egg stands.

	The game builds it into Workspace.World when a server starts. To see it while editing in
	Studio (so you can build around it), paste this into the Command Bar (View → Command Bar):

		print(require(game.ServerScriptService.Server.MapBuilder).togglePreview())

	Run it again to remove the preview. The preview is only a guide: it's deleted when the game
	starts, and edits to it are never kept. Save your own builds into Workspace.StudioBuilds.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CustomModels = require(Shared.CustomModels)
local Eggs = require(Shared.Eggs)
local Format = require(Shared.Format)
local Zones = require(Shared.Zones)

local MapBuilder = {}

MapBuilder.PreviewName = "MapPreview"

export type Result = {
	-- [zoneIndex] = unlock prompts along that zone's gate
	Gates: { [number]: { ProximityPrompt } },
	-- [eggId] = hatch prompts and where the egg stands
	EggPrompts: { [string]: { Single: ProximityPrompt, Triple: ProximityPrompt, Position: Vector3 } },
	-- [boardName] = row labels, filled by LeaderboardService
	Boards: { [string]: { TextLabel } },
}

-- Set for the duration of MapBuilder.build.
local root: Instance
local preview = false
local result: Result

-- Tags drive client behaviour (egg odds boards, gates), so a preview never gets them.
local function tag(instance: Instance, name: string)
	if not preview then
		CollectionService:AddTag(instance, name)
	end
end

local WIDTH = Zones.Layout.Width
local LENGTH = Zones.Layout.Length
local EGG_OFFSET = 60
local rgb = Color3.fromRGB

local function part(props: { [string]: any }): Part
	local newPart = Instance.new("Part")
	newPart.Anchored = true
	newPart.TopSurface = Enum.SurfaceType.Smooth
	newPart.BottomSurface = Enum.SurfaceType.Smooth
	newPart.Material = Enum.Material.SmoothPlastic
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(newPart :: any)[key] = value
		end
	end
	newPart.Parent = parent
	return newPart
end

function MapBuilder.eggPosition(zoneIndex: number): Vector3
	return Vector3.new(0, 0, (zoneIndex - 1) * LENGTH + EGG_OFFSET)
end

function MapBuilder.textLabel(props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.4
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(label :: any)[key] = value
		end
	end
	label.Parent = parent
	return label
end

-- Random spot in a zone that keeps clear of the centre path, the egg and the spawn plaza.
local function scatterPoint(rng: Random, zoneIndex: number): Vector3?
	local zoneStart = (zoneIndex - 1) * LENGTH
	local egg = MapBuilder.eggPosition(zoneIndex)
	for _ = 1, 20 do
		local x = rng:NextNumber(-WIDTH / 2 + 8, WIDTH / 2 - 8)
		local z = rng:NextNumber(zoneStart + 10, zoneStart + LENGTH - 10)
		local point = Vector3.new(x, 0, z)
		local nearPath = math.abs(x) < 14
		local nearEgg = (point - egg).Magnitude < 24
		local nearSpawn = zoneIndex == 1 and z < 55 and math.abs(x) < 48
		if not (nearPath or nearEgg or nearSpawn) then
			return point
		end
	end
	return nil
end

local function cylinder(size: Vector3, cframe: CFrame, color: Color3, parent: Instance, extra: { [string]: any }?): Part
	local props: { [string]: any } = {
		Shape = Enum.PartType.Cylinder,
		Size = size,
		CFrame = cframe * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Parent = parent,
	}
	if extra then
		for key, value in extra do
			props[key] = value
		end
	end
	return part(props)
end

local function ball(
	diameter: number,
	position: Vector3,
	color: Color3,
	parent: Instance,
	extra: { [string]: any }?
): Part
	local props: { [string]: any } = {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * diameter,
		CFrame = CFrame.new(position),
		Color = color,
		Parent = parent,
	}
	if extra then
		for key, value in extra do
			props[key] = value
		end
	end
	return part(props)
end

local DECOR: { [string]: (Folder, Random, number) -> () } = {}

DECOR.Meadow = function(folder, rng, zoneIndex)
	local leafColors = { rgb(90, 180, 70), rgb(70, 160, 60), rgb(120, 200, 80) }
	local flowerColors = { rgb(255, 120, 170), rgb(255, 230, 80), rgb(255, 255, 255), rgb(190, 120, 255) }
	for _ = 1, 22 do
		local point = scatterPoint(rng, zoneIndex)
		if point then
			local height = rng:NextNumber(6, 10)
			cylinder(
				Vector3.new(height, 1.8, 1.8),
				CFrame.new(point + Vector3.new(0, height / 2, 0)),
				rgb(120, 80, 50),
				folder
			)
			ball(
				rng:NextNumber(7, 10),
				point + Vector3.new(0, height + 2, 0),
				leafColors[rng:NextInteger(1, #leafColors)],
				folder,
				{ Material = Enum.Material.Grass, CanCollide = false }
			)
		end
	end
	for _ = 1, 40 do
		local point = scatterPoint(rng, zoneIndex)
		if point then
			ball(
				rng:NextNumber(0.8, 1.4),
				point + Vector3.new(0, 0.5, 0),
				flowerColors[rng:NextInteger(1, #flowerColors)],
				folder,
				{ CanCollide = false }
			)
		end
	end
end

DECOR.Candy = function(folder, rng, zoneIndex)
	local candyColors =
		{ rgb(255, 100, 170), rgb(120, 220, 255), rgb(255, 230, 90), rgb(150, 255, 150), rgb(200, 130, 255) }
	for _ = 1, 20 do
		local point = scatterPoint(rng, zoneIndex)
		if point then
			local height = rng:NextNumber(6, 11)
			cylinder(
				Vector3.new(height, 0.8, 0.8),
				CFrame.new(point + Vector3.new(0, height / 2, 0)),
				rgb(255, 255, 255),
				folder
			)
			local disc = rng:NextNumber(5, 8)
			part({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1, disc, disc),
				CFrame = CFrame.new(point + Vector3.new(0, height + disc / 2 - 0.5, 0))
					* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				Color = candyColors[rng:NextInteger(1, #candyColors)],
				CanCollide = false,
				Parent = folder,
			})
		end
	end
	for _ = 1, 26 do
		local point = scatterPoint(rng, zoneIndex)
		if point then
			ball(
				rng:NextNumber(2.5, 4.5),
				point + Vector3.new(0, 0.6, 0),
				candyColors[rng:NextInteger(1, #candyColors)],
				folder,
				{ Material = Enum.Material.Glass, Transparency = 0.15 }
			)
		end
	end
end

DECOR.Frost = function(folder, rng, zoneIndex)
	for _ = 1, 22 do
		local point = scatterPoint(rng, zoneIndex)
		if point then
			cylinder(Vector3.new(3, 1.4, 1.4), CFrame.new(point + Vector3.new(0, 1.5, 0)), rgb(110, 80, 60), folder)
			for tier = 0, 2 do
				local size = 7 - tier * 1.8
				part({
					Size = Vector3.new(size, 2.6, size),
					CFrame = CFrame.new(point + Vector3.new(0, 4 + tier * 2.2, 0))
						* CFrame.Angles(0, math.rad(45 * tier), 0),
					Color = if tier == 2 then rgb(250, 252, 255) else rgb(200, 230, 225),
					Material = Enum.Material.Snow,
					CanCollide = tier == 0,
					Parent = folder,
				})
			end
		end
	end
	for _ = 1, 18 do
		local point = scatterPoint(rng, zoneIndex)
		if point then
			local height = rng:NextNumber(4, 10)
			part({
				Size = Vector3.new(2, height, 2),
				CFrame = CFrame.new(point + Vector3.new(0, height / 2 - 0.5, 0))
					* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
				Color = rgb(150, 215, 255),
				Material = Enum.Material.Ice,
				Transparency = 0.2,
				Parent = folder,
			})
		end
	end
	for _ = 1, 5 do
		local point = scatterPoint(rng, zoneIndex)
		if point then
			ball(3.2, point + Vector3.new(0, 1.4, 0), rgb(250, 250, 255), folder, { Material = Enum.Material.Snow })
			ball(2.4, point + Vector3.new(0, 3.8, 0), rgb(250, 250, 255), folder, { Material = Enum.Material.Snow })
			ball(1.7, point + Vector3.new(0, 5.6, 0), rgb(250, 250, 255), folder, { Material = Enum.Material.Snow })
			part({
				Size = Vector3.new(0.3, 0.3, 1),
				CFrame = CFrame.new(point + Vector3.new(0, 5.6, -1)),
				Color = rgb(255, 140, 40),
				Parent = folder,
			})
		end
	end
end

DECOR.Lava = function(folder, rng, zoneIndex)
	for _ = 1, 26 do
		local point = scatterPoint(rng, zoneIndex)
		if point then
			part({
				Size = Vector3.new(rng:NextNumber(3, 8), rng:NextNumber(2, 6), rng:NextNumber(3, 8)),
				CFrame = CFrame.new(point + Vector3.new(0, 1, 0))
					* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(-0.4, 0.4)),
				Color = rgb(55, 40, 40),
				Material = Enum.Material.Basalt,
				Parent = folder,
			})
		end
	end
	for _ = 1, 12 do
		local point = scatterPoint(rng, zoneIndex)
		if point then
			local diameter = rng:NextNumber(8, 16)
			cylinder(
				Vector3.new(0.3, diameter, diameter),
				CFrame.new(point + Vector3.new(0, 0.05, 0)),
				rgb(255, 110, 20),
				folder,
				{ Material = Enum.Material.Neon, CanCollide = false }
			)
		end
	end
	local zoneStart = (zoneIndex - 1) * LENGTH
	for side = -1, 1, 2 do
		local base = Vector3.new(side * 72, 0, zoneStart + 140)
		for tier = 0, 3 do
			local diameter = 44 - tier * 9
			cylinder(
				Vector3.new(8, diameter, diameter),
				CFrame.new(base + Vector3.new(0, 4 + tier * 8, 0)),
				rgb(70 - tier * 5, 45, 40),
				folder,
				{ Material = Enum.Material.Basalt }
			)
		end
		cylinder(
			Vector3.new(0.5, 14, 14),
			CFrame.new(base + Vector3.new(0, 32.3, 0)),
			rgb(255, 120, 20),
			folder,
			{ Material = Enum.Material.Neon }
		)
	end
end

DECOR.Cosmic = function(folder, rng, zoneIndex)
	local glow = { rgb(170, 80, 255), rgb(0, 255, 225), rgb(255, 90, 220), rgb(90, 140, 255) }
	for _ = 1, 26 do
		local point = scatterPoint(rng, zoneIndex)
		if point then
			local height = rng:NextNumber(4, 12)
			part({
				Size = Vector3.new(1.6, height, 1.6),
				CFrame = CFrame.new(point + Vector3.new(0, height / 2 - 0.5, 0)) * CFrame.Angles(
					rng:NextNumber(-0.35, 0.35),
					rng:NextNumber(0, math.pi),
					rng:NextNumber(-0.35, 0.35)
				),
				Color = glow[rng:NextInteger(1, #glow)],
				Material = Enum.Material.Neon,
				Parent = folder,
			})
		end
	end
	local zoneStart = (zoneIndex - 1) * LENGTH
	for _ = 1, 6 do
		local diameter = rng:NextNumber(8, 18)
		local position = Vector3.new(
			rng:NextNumber(-90, 90),
			rng:NextNumber(30, 55),
			rng:NextNumber(zoneStart + 20, zoneStart + LENGTH - 20)
		)
		ball(
			diameter,
			position,
			glow[rng:NextInteger(1, #glow)],
			folder,
			{ CanCollide = false, Material = Enum.Material.SmoothPlastic }
		)
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, diameter * 1.9, diameter * 1.9),
			CFrame = CFrame.new(position)
				* CFrame.Angles(rng:NextNumber(-0.5, 0.5), 0, math.rad(90) + rng:NextNumber(-0.4, 0.4)),
			Color = rgb(255, 255, 255),
			Transparency = 0.5,
			CanCollide = false,
			Parent = folder,
		})
	end
	for _ = 1, 60 do
		local position = Vector3.new(
			rng:NextNumber(-110, 110),
			rng:NextNumber(35, 90),
			rng:NextNumber(zoneStart, zoneStart + LENGTH)
		)
		ball(
			rng:NextNumber(0.4, 1),
			position,
			rgb(255, 255, 255),
			folder,
			{ Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }
		)
	end
end

local function buildZone(zone)
	local folder = Instance.new("Folder")
	folder.Name = zone.Name
	folder.Parent = root
	local zoneStart = (zone.Index - 1) * LENGTH

	part({
		Name = "Ground",
		Size = Vector3.new(WIDTH, 4, LENGTH),
		CFrame = CFrame.new(0, -2, zoneStart + LENGTH / 2),
		Color = zone.Ground,
		Material = zone.GroundMaterial,
		Parent = folder,
	})
	part({
		Name = "Path",
		Size = Vector3.new(16, 0.2, LENGTH),
		CFrame = CFrame.new(0, 0.05, zoneStart + LENGTH / 2),
		Color = zone.Ground:Lerp(Color3.new(1, 1, 1), 0.35),
		CanCollide = false,
		Parent = folder,
	})

	local decor = DECOR[zone.Theme]
	if decor then
		decor(folder, Random.new(zone.Index * 7919), zone.Index)
	end
end

local function buildBoundaries()
	local total = #Zones.List * LENGTH
	local function wall(size: Vector3, position: Vector3)
		part({ Name = "Boundary", Size = size, CFrame = CFrame.new(position), Transparency = 1, Parent = root })
	end
	wall(Vector3.new(2, 120, total), Vector3.new(-WIDTH / 2 - 1, 60, total / 2))
	wall(Vector3.new(2, 120, total), Vector3.new(WIDTH / 2 + 1, 60, total / 2))
	wall(Vector3.new(WIDTH, 120, 2), Vector3.new(0, 60, -1))
	wall(Vector3.new(WIDTH, 120, 2), Vector3.new(0, 60, total + 1))
end

local function buildSpawn()
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(14, 1, 14)
	-- Rotated so players face into the map.
	spawn.CFrame = CFrame.new(0, 0.5, 16) * CFrame.Angles(0, math.pi, 0)
	spawn.Color = rgb(255, 230, 120)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Enabled = not preview
	spawn.Parent = root

	-- Welcome arch
	for side = -1, 1, 2 do
		part({
			Name = "ArchPillar",
			Size = Vector3.new(3, 16, 3),
			CFrame = CFrame.new(side * 12, 8, 32),
			Color = rgb(255, 255, 255),
			Parent = root,
		})
	end
	local beam = part({
		Name = "ArchSign",
		Size = Vector3.new(30, 5, 3),
		CFrame = CFrame.new(0, 17.5, 32),
		Color = rgb(255, 170, 40),
		Parent = root,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = beam
	MapBuilder.textLabel({
		Size = UDim2.fromScale(1, 1),
		Text = "🥚 " .. string.upper(Config.GameName) .. " 🐾",
		Parent = gui,
	})
end

local function buildBoard(name: string, title: string, cframe: CFrame)
	local board = part({
		Name = name,
		Size = Vector3.new(16, 21, 1),
		CFrame = cframe,
		Color = rgb(35, 35, 55),
		Parent = root,
	})
	part({
		Name = name .. "Post",
		Size = Vector3.new(1.5, 4, 1.5),
		CFrame = cframe * CFrame.new(0, -12, 0.5),
		Color = rgb(35, 35, 55),
		Parent = root,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	MapBuilder.textLabel({
		Size = UDim2.new(1, -40, 0, 90),
		Position = UDim2.fromOffset(20, 16),
		Text = title,
		TextColor3 = rgb(255, 215, 80),
		Parent = gui,
	})
	local rows = {}
	for index = 1, 10 do
		rows[index] = MapBuilder.textLabel({
			Name = "Row" .. index,
			Size = UDim2.new(1, -60, 0, 60),
			Position = UDim2.fromOffset(30, 120 + (index - 1) * 68),
			Text = index .. ". ...",
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = gui,
		})
	end
	result.Boards[name] = rows
end

local function buildGates()
	for index = 2, #Zones.List do
		local zone = Zones.List[index]
		local z = (index - 1) * LENGTH
		local gate = part({
			Name = "Gate" .. index,
			Size = Vector3.new(WIDTH, 40, 2),
			CFrame = CFrame.new(0, 20, z),
			Color = zone.Accent,
			Material = Enum.Material.ForceField,
			Parent = root,
		})
		gate:SetAttribute("Zone", index)
		tag(gate, "ZoneGate")

		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Instance.new("SurfaceGui")
			gui.Name = "Sign"
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 10
			gui.LightInfluence = 0
			gui.Parent = gate
			MapBuilder.textLabel({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.35),
				Size = UDim2.fromOffset(900, 220),
				Text = string.format("🔒 %s %s\n🪙 %s", zone.Icon, zone.Name, Format.number(zone.UnlockCost)),
				Parent = gui,
			})
		end

		local prompts = {}
		for _, x in { -60, 0, 60 } do
			local attachment = Instance.new("Attachment")
			attachment.Position = Vector3.new(x, -16, -1.5)
			attachment.Parent = gate
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Unlock " .. zone.Name
			prompt.ObjectText = "🪙 " .. Format.number(zone.UnlockCost)
			prompt.HoldDuration = 0.25
			prompt.MaxActivationDistance = 16
			prompt.RequiresLineOfSight = false
			prompt.Parent = attachment
			table.insert(prompts, prompt)
		end
		result.Gates[index] = prompts
	end
end

local function buildEggStand(egg)
	local base = MapBuilder.eggPosition(egg.Zone)
	local zone = Zones.List[egg.Zone]
	local model = Instance.new("Model")
	model.Name = egg.Id .. "EggStand"
	model:SetAttribute("EggId", egg.Id)

	cylinder(
		Vector3.new(3, 12, 12),
		CFrame.new(base + Vector3.new(0, 1.5, 0)),
		zone.Accent:Lerp(Color3.new(1, 1, 1), 0.5),
		model
	)
	cylinder(
		Vector3.new(0.6, 12.6, 12.6),
		CFrame.new(base + Vector3.new(0, 3, 0)),
		egg.Accent,
		model,
		{ Material = Enum.Material.Neon }
	)

	-- Your own egg from ReplicatedStorage.EggModels if there is one, otherwise a generated egg.
	local eggModel = CustomModels.get("EggModels", egg.Id, 7, true)
	if eggModel then
		eggModel:PivotTo(CFrame.new(base + Vector3.new(0, 6.8, 0)))
	else
		eggModel = Instance.new("Model")
		eggModel.Name = "Egg"
		local shell = part({
			Name = "Shell",
			Size = Vector3.new(5.5, 7, 5.5),
			CFrame = CFrame.new(base + Vector3.new(0, 6.8, 0)),
			Color = egg.Color,
			CanCollide = false,
			Parent = eggModel,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = shell
		cylinder(
			Vector3.new(0.7, 5.6, 5.6),
			CFrame.new(base + Vector3.new(0, 6.8, 0)),
			egg.Accent,
			eggModel,
			{ CanCollide = false }
		)
		for index = 1, 4 do
			local angle = index * math.pi / 2 + math.pi / 4
			ball(
				1.1,
				base + Vector3.new(math.cos(angle) * 2.35, 8.6, math.sin(angle) * 2.35),
				egg.Accent,
				eggModel,
				{ CanCollide = false }
			)
		end
		eggModel.PrimaryPart = shell
	end
	eggModel.Name = "Egg"
	eggModel.Parent = model

	local promptAnchor = part({
		Name = "PromptAnchor",
		Size = Vector3.one,
		CFrame = CFrame.new(base + Vector3.new(0, 3, 0)),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	local function prompt(action: string, key: Enum.KeyCode, offsetX: number): ProximityPrompt
		local attachment = Instance.new("Attachment")
		attachment.Parent = promptAnchor
		local newPrompt = Instance.new("ProximityPrompt")
		newPrompt.ActionText = action
		newPrompt.ObjectText = egg.Name .. " · 🪙 " .. Format.number(egg.Price)
		newPrompt.KeyboardKeyCode = key
		newPrompt.HoldDuration = 0
		newPrompt.MaxActivationDistance = 14
		newPrompt.RequiresLineOfSight = false
		newPrompt.UIOffset = Vector2.new(offsetX, 0)
		newPrompt.Parent = attachment
		return newPrompt
	end
	local single = prompt("Hatch x1", Enum.KeyCode.E, -100)
	local triple = prompt("Hatch x3", Enum.KeyCode.R, 100)
	triple.GamepadKeyCode = Enum.KeyCode.ButtonY

	model.Parent = root
	tag(model, "EggStand")
	result.EggPrompts[egg.Id] = { Single = single, Triple = triple, Position = base }
end

function MapBuilder.setupLighting()
	local first = Zones.List[1]
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = first.AtmosphereDensity
	atmosphere.Color = first.AtmosphereColor
	atmosphere.Decay = first.AtmosphereDecay
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 1.3
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.15
	color.Contrast = 0.05
	color.Parent = Lighting
end

function MapBuilder.build(parent: Instance, isPreview: boolean): Result
	root = parent
	preview = isPreview
	result = { Gates = {}, EggPrompts = {}, Boards = {} }

	for _, zone in Zones.List do
		buildZone(zone)
	end
	buildBoundaries()
	buildSpawn()
	buildBoard("RebirthBoard", "🔁 Top Rebirths", CFrame.new(-34, 12.5, 46) * CFrame.Angles(0, math.rad(-20), 0))
	buildBoard("EggBoard", "🥚 Top Hatchers", CFrame.new(34, 12.5, 46) * CFrame.Angles(0, math.rad(20), 0))
	buildGates()
	for _, egg in Eggs.List do
		buildEggStand(egg)
	end
	return result
end

-- Adds or removes a locked, edit-mode copy of the map in Workspace.MapPreview.
function MapBuilder.togglePreview(): string
	local existing = workspace:FindFirstChild(MapBuilder.PreviewName)
	if existing then
		existing:Destroy()
		return "Map preview removed."
	end
	local folder = Instance.new("Folder")
	folder.Name = MapBuilder.PreviewName
	MapBuilder.build(folder, true)
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Locked = true
		end
	end
	folder.Parent = workspace
	return "Map preview added to Workspace.MapPreview (locked, deleted when the game runs). Run again to remove it."
end

return MapBuilder
