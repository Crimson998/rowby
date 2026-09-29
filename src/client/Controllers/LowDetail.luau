--!strict
--[[
	Low-detail mode: hides the map decorations (tagged "Decor" by MapBuilder) for smoother play
	on low-end phones. Pet sparkles are handled in PetFollow.
]]

local CollectionService = game:GetService("CollectionService")

local State = require(script.Parent.Parent.State)

local LowDetail = {}

local function apply(folder: Instance, hidden: boolean)
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = if hidden then 1 else 0
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Light") or descendant:IsA("Sparkles") then
			(descendant :: any).Enabled = not hidden
		end
	end
end

local function isHidden(): boolean
	local settings = State.Data.Settings
	return settings ~= nil and settings.LowDetail == true
end

function LowDetail.start()
	local function refresh()
		local hidden = isHidden()
		for _, folder in CollectionService:GetTagged("Decor") do
			apply(folder, hidden)
		end
	end
	CollectionService:GetInstanceAddedSignal("Decor"):Connect(function(folder)
		-- Decorations stream in after the tag, so wait a moment before hiding them.
		task.delay(1, function()
			apply(folder, isHidden())
		end)
	end)
	State.watch({ "Settings" }, refresh)
	refresh()
end

return LowDetail
