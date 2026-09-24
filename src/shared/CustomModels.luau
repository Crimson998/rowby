--[[
	Lets you replace the generated pets and eggs with your own models.

	Put a Model (or a single MeshPart) in ReplicatedStorage.PetModels named after the pet id
	from Pets.luau (e.g. "Doggy"), or in ReplicatedStorage.EggModels named after the egg id
	from Eggs.luau (e.g. "Meadow"). Anything missing keeps its generated look.

	- The model's front is the direction its pivot faces (the pivot's LookVector, -Z).
	- It is resized to fit, unless you set a boolean attribute KeepScale = true on it.
	- Golden pets use "<PetId>_Golden" if it exists, otherwise the model is painted gold.
	- Scripts inside the model are removed, so Toolbox models can't run code.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomModels = {}

local GOLD = Color3.fromRGB(255, 200, 45)

local function find(folderName: string, name: string): Instance?
	local folder = ReplicatedStorage:FindFirstChild(folderName)
	return folder and folder:FindFirstChild(name)
end

local function paintGold(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("SurfaceAppearance") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Color = GOLD
			descendant.Material = Enum.Material.SmoothPlastic
			descendant.Reflectance = 0.3
			if descendant:IsA("MeshPart") then
				descendant.TextureID = ""
			end
		end
	end
end

--[[
	Returns a ready-to-use clone of a custom model, or nil if there isn't one.
	`size` is the largest dimension it's scaled to. With `anchorAll` every part is anchored
	(static props); otherwise only the invisible Root is, and everything else is welded to it
	so moving Root moves the whole model.
]]
function CustomModels.get(folderName: string, name: string, size: number, anchorAll: boolean, golden: boolean?): Model?
	local source = if golden then find(folderName, name .. "_Golden") else nil
	local paint = golden == true and source == nil
	source = source or find(folderName, name)
	if not source then
		return nil
	end

	local model: Model
	if source:IsA("Model") then
		model = source:Clone()
	elseif source:IsA("BasePart") then
		model = Instance.new("Model")
		source:Clone().Parent = model
		model.WorldPivot = source:GetPivot()
	else
		warn(string.format("[CustomModels] %s.%s must be a Model or a part", folderName, name))
		return nil
	end
	model.Name = name

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end

	local parts = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	if #parts == 0 then
		warn(string.format("[CustomModels] %s.%s has no parts", folderName, name))
		return nil
	end

	if model:GetAttribute("KeepScale") ~= true then
		local extents = model:GetExtentsSize()
		local largest = math.max(extents.X, extents.Y, extents.Z)
		if largest > 0 then
			model:ScaleTo(model:GetScale() * size / largest)
		end
	end
	if paint then
		paintGold(model)
	end

	-- An invisible Root at the centre of the model, facing the model's front.
	local boxCFrame = model:GetBoundingBox()
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.2
	root.Transparency = 1
	root.CFrame = CFrame.new(boxCFrame.Position) * model:GetPivot().Rotation
	root.Parent = model

	for _, part in parts do
		part.Anchored = anchorAll
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Massless = true
		if not anchorAll then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	model.PrimaryPart = root
	model.WorldPivot = root.CFrame
	return model
end

return CustomModels
