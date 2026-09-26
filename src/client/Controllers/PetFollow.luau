--!strict
--[[
	Renders every player's equipped pets hopping along behind them. Pets are local models built
	from each player's "EquippedPets" attribute, so they cost the server nothing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Pets = require(Shared.Pets)

local PetModels = require(script.Parent.Parent.PetModels)
local State = require(script.Parent.Parent.State)

local PetFollow = {}

type Rendered = { Key: string, Models: { Model }, Current: { CFrame } }

local PER_ROW = 4
local SPACING = 3.2
local BEHIND = 5

local folder: Folder
local rendered: { [Player]: Rendered } = {}

local function clear(player: Player)
	local entry = rendered[player]
	if entry then
		for _, model in entry.Models do
			model:Destroy()
		end
		rendered[player] = nil
	end
end

local function build(player: Player, key: string): Rendered
	clear(player)
	local entry: Rendered = { Key = key, Models = {}, Current = {} }
	for token in string.gmatch(key, "[^,]+") do
		-- "Doggy" or "Doggy:3" (tier 3)
		local petId, tierText = string.match(token, "^([^:]+):?(%d*)$")
		if petId and Pets[petId] then
			local tier = tonumber(tierText) or 1
			local model = PetModels.pet(petId, tier)
			local rarity = Pets[petId].Rarity
			local tierDef = Config.Tiers[tier] or Config.Tiers[1]
			if tier > 1 or Config.Rarities[rarity].Announce then
				local sparkles = Instance.new("Sparkles")
				sparkles.SparkleColor = if tier > 1 then tierDef.Accent else Config.Rarities[rarity].Color
				sparkles.Parent = model.PrimaryPart
			end
			model.Parent = folder
			table.insert(entry.Models, model)
		end
	end
	rendered[player] = entry
	return entry
end

local function update(dt: number)
	local now = os.clock()
	local alpha = 1 - math.exp(-dt * 10)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local key = player:GetAttribute("EquippedPets")
		local settings = State.Data.Settings
		local hidden = player ~= Players.LocalPlayer and settings ~= nil and settings.ShowOtherPets == false
		if hidden or not root or type(key) ~= "string" or key == "" then
			clear(player)
			continue
		end
		local entry = rendered[player]
		if not entry or entry.Key ~= key then
			entry = build(player, key)
		end

		local count = #entry.Models
		local moving = root.AssemblyLinearVelocity.Magnitude > 2
		local flatLook = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if flatLook.Magnitude < 0.01 then
			flatLook = Vector3.new(0, 0, -1)
		end
		local facing = CFrame.lookAt(root.Position, root.Position + flatLook)

		for index, model in entry.Models do
			local row = (index - 1) // PER_ROW
			local column = (index - 1) % PER_ROW
			local inRow = math.min(PER_ROW, count - row * PER_ROW)
			local offsetX = (column - (inRow - 1) / 2) * SPACING
			local offsetZ = BEHIND + row * SPACING
			local hop = if moving then math.abs(math.sin(now * 9 + index)) * 1.1 else math.sin(now * 3 + index) * 0.3
			local target = facing * CFrame.new(offsetX, -1.6 + hop, offsetZ)
			local current = entry.Current[index] or target
			current = current:Lerp(target, alpha)
			entry.Current[index] = current
			local petRoot = model.PrimaryPart
			if petRoot then
				petRoot.CFrame = current
			end
		end
	end
end

function PetFollow.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalPets"
	folder.Parent = workspace
	Players.PlayerRemoving:Connect(clear)
	RunService.RenderStepped:Connect(update)
end

return PetFollow
