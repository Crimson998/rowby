--[[
	Builds cute pet and egg models from their definitions, so adding a pet only needs data.
	Your own models in ReplicatedStorage.PetModels / EggModels take priority (see CustomModels).
	Models face -Z. The body ("Root") is the PrimaryPart and every other part is welded to it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CustomModels = require(Shared.CustomModels)
local Eggs = require(Shared.Eggs)
local Pets = require(Shared.Pets)

local PetModels = {}

local rgb = Color3.fromRGB
local BLACK = rgb(25, 25, 30)
local WHITE = rgb(255, 255, 255)
local BLUSH = rgb(255, 140, 160)
local GOLD = rgb(255, 200, 45)
local GOLD_ACCENT = rgb(255, 240, 160)
local BEAK = rgb(255, 170, 40)

local function newPart(model: Model, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = model
	return part
end

local function ball(model: Model, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	return newPart(model, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * diameter,
		CFrame = cframe,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

local function ellipsoid(model: Model, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = newPart(
		model,
		{ Size = size, CFrame = cframe, Color = color, Material = material or Enum.Material.SmoothPlastic }
	)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function block(model: Model, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	return newPart(
		model,
		{ Size = size, CFrame = cframe, Color = color, Material = material or Enum.Material.SmoothPlastic }
	)
end

-- Vertical cylinder of the given height and diameter centred on cframe.
local function cylinder(
	model: Model,
	height: number,
	diameter: number,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	return newPart(model, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = cframe * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

type FeatureBuilder = (model: Model, color: Color3, accent: Color3, material: Enum.Material) -> ()

local FEATURES: { [string]: FeatureBuilder } = {
	DogEars = function(model, _, accent, material)
		for side = -1, 1, 2 do
			ellipsoid(
				model,
				Vector3.new(0.35, 1, 0.65),
				CFrame.new(side * 1, 0.25, 0) * CFrame.Angles(0, 0, side * math.rad(20)),
				accent,
				material
			)
		end
	end,
	CatEars = function(model, color, accent, material)
		for side = -1, 1, 2 do
			block(
				model,
				Vector3.new(0.62, 0.62, 0.24),
				CFrame.new(side * 0.55, 0.95, -0.05) * CFrame.Angles(0, 0, math.rad(45)),
				color
			)
			block(
				model,
				Vector3.new(0.34, 0.34, 0.1),
				CFrame.new(side * 0.55, 0.98, -0.2) * CFrame.Angles(0, 0, math.rad(45)),
				accent,
				material
			)
		end
	end,
	BunnyEars = function(model, color, accent, material)
		for side = -1, 1, 2 do
			local cframe = CFrame.new(side * 0.4, 1.55, 0) * CFrame.Angles(0, 0, side * math.rad(-8))
			ellipsoid(model, Vector3.new(0.45, 1.5, 0.28), cframe, color)
			ellipsoid(model, Vector3.new(0.25, 1.1, 0.1), cframe * CFrame.new(0, 0, -0.12), accent, material)
		end
	end,
	BearEars = function(model, color, accent, material)
		for side = -1, 1, 2 do
			ball(model, 0.65, CFrame.new(side * 0.7, 0.85, 0), color)
			ball(model, 0.35, CFrame.new(side * 0.72, 0.87, -0.2), accent, material)
		end
	end,
	Wings = function(model, _, accent, material)
		for side = -1, 1, 2 do
			local wing = ellipsoid(
				model,
				Vector3.new(0.18, 1, 1.4),
				CFrame.new(side * 1.25, 0.35, 0.35) * CFrame.Angles(math.rad(-10), 0, side * math.rad(-35)),
				accent,
				material
			)
			wing.Transparency = 0.1
		end
	end,
	Antenna = function(model, _, accent, material)
		for side = -1, 1, 2 do
			cylinder(
				model,
				0.8,
				0.12,
				CFrame.new(side * 0.38, 1.35, 0) * CFrame.Angles(0, 0, side * math.rad(-15)),
				BLACK
			)
			ball(model, 0.32, CFrame.new(side * 0.5, 1.75, 0), accent, material)
		end
	end,
	Horns = function(model, _, accent, material)
		for side = -1, 1, 2 do
			block(
				model,
				Vector3.new(0.28, 0.75, 0.28),
				CFrame.new(side * 0.55, 1.1, -0.15) * CFrame.Angles(0, 0, side * math.rad(-25)),
				accent,
				material
			)
		end
	end,
	Horn = function(model, _, accent, material)
		ellipsoid(
			model,
			Vector3.new(0.3, 1.1, 0.3),
			CFrame.new(0, 1.25, -0.55) * CFrame.Angles(math.rad(-30), 0, 0),
			accent,
			material
		)
	end,
	Halo = function(model)
		local halo = cylinder(model, 0.12, 1.5, CFrame.new(0, 1.8, 0), GOLD_ACCENT, Enum.Material.Neon)
		halo.Transparency = 0.2
	end,
	Beak = function(model)
		block(
			model,
			Vector3.new(0.45, 0.25, 0.45),
			CFrame.new(0, -0.12, -1.05) * CFrame.Angles(0, math.rad(45), 0),
			BEAK
		)
	end,
	Crown = function(model, _, accent, material)
		cylinder(model, 0.45, 0.95, CFrame.new(0, 1.2, 0), GOLD, Enum.Material.SmoothPlastic)
		for index = 1, 4 do
			local angle = index * math.pi / 2
			block(
				model,
				Vector3.new(0.18, 0.35, 0.18),
				CFrame.new(math.cos(angle) * 0.38, 1.55, math.sin(angle) * 0.38),
				GOLD
			)
		end
		ball(model, 0.2, CFrame.new(0, 1.2, -0.47), accent, material)
	end,
	Tentacles = function(model, _, accent, material)
		for index = 1, 4 do
			local angle = index * math.pi / 2 + math.pi / 4
			cylinder(
				model,
				0.9,
				0.28,
				CFrame.new(math.cos(angle) * 0.55, -1.15, math.sin(angle) * 0.55),
				accent,
				material
			)
		end
	end,
}

-- `tier` is 1 (Normal) up to #Config.Tiers; higher tiers repaint the pet in the tier's colours.
function PetModels.pet(petId: string, tier: number?): Model
	local custom = CustomModels.get("PetModels", petId, 2.6, false, tier)
	if custom then
		return custom
	end

	local def = Pets[petId]
	local model = Instance.new("Model")
	model.Name = petId

	local tierDef = Config.Tiers[tier or 1] or Config.Tiers[1]
	local upgraded = tierDef.Color ~= nil
	local color = if upgraded then tierDef.Color else def.Color
	local accent = if upgraded then tierDef.Accent else def.Accent
	local accentMaterial = if def.Neon or tierDef.NeonAccent then Enum.Material.Neon else Enum.Material.SmoothPlastic

	local body: Part
	local faceZ: number
	if def.Shape == "Blob" then
		body = ellipsoid(model, Vector3.new(2.6, 1.9, 2.6), CFrame.new(0, -0.15, 0), color)
		faceZ = -1.08
	else
		body = ball(model, 2.2, CFrame.new(), color)
		faceZ = -0.95
	end
	body.Name = "Root"
	body.Anchored = true
	if upgraded then
		body.Reflectance = tierDef.Reflectance or 0.25
	end
	model.PrimaryPart = body

	for side = -1, 1, 2 do
		ball(model, 0.42, CFrame.new(side * 0.42, 0.22, faceZ), BLACK)
		ball(model, 0.16, CFrame.new(side * 0.36, 0.32, faceZ - 0.18), WHITE)
		ellipsoid(model, Vector3.new(0.35, 0.2, 0.1), CFrame.new(side * 0.68, -0.12, faceZ + 0.12), BLUSH)
	end

	for _, feature in def.Features do
		local builder = FEATURES[feature]
		if builder then
			builder(model, color, accent, accentMaterial)
		end
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= body then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	return model
end

function PetModels.egg(eggId: string): Model
	local custom = CustomModels.get("EggModels", eggId, 2.8, false)
	if custom then
		return custom
	end

	local egg = Eggs.ById[eggId]
	local model = Instance.new("Model")
	model.Name = eggId .. "Egg"
	local shell = ellipsoid(model, Vector3.new(2.2, 2.8, 2.2), CFrame.new(), egg.Color)
	shell.Name = "Root"
	shell.Anchored = true
	model.PrimaryPart = shell
	cylinder(model, 0.3, 2.26, CFrame.new(), egg.Accent)
	for index = 1, 4 do
		local angle = index * math.pi / 2 + math.pi / 4
		ball(model, 0.45, CFrame.new(math.cos(angle) * 0.95, 0.72, math.sin(angle) * 0.95), egg.Accent)
	end
	return model
end

-- Every pet that can appear in the index, in egg order, followed by exclusives.
function PetModels.indexOrder(): { string }
	local order = {}
	local seen = {}
	for _, egg in Eggs.List do
		for _, entry in egg.Pets do
			if not seen[entry.Id] then
				seen[entry.Id] = true
				table.insert(order, entry.Id)
			end
		end
	end
	for petId, def in Pets do
		if def.Exclusive and not seen[petId] then
			table.insert(order, petId)
		end
	end
	return order
end

return PetModels
