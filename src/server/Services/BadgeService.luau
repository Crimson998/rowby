--!strict
--[[
	Roblox badges for first hatch, each area, first rebirth, a Secret pet and a full Pet Index.
	Ids live in Config.Badges (0 = not set up yet). Roblox ignores repeat awards, but each badge
	is still only tried once per player per visit. Every call is wrapped in pcall; badges must
	never break gameplay.
]]

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Pets = require(Shared.Pets)

local DataService = require(script.Parent.DataService)

local Badges = {}

local tried: { [Player]: { [number]: boolean } } = {}

local function award(player: Player, badgeId: number?)
	local done = tried[player]
	if not done or not badgeId or badgeId <= 0 or done[badgeId] then
		return
	end
	done[badgeId] = true
	task.spawn(function()
		pcall(function()
			BadgeService:AwardBadge(player.UserId, badgeId)
		end)
	end)
end

function Badges.firstHatch(player: Player)
	award(player, Config.Badges.FirstHatch)
end

function Badges.firstRebirth(player: Player)
	award(player, Config.Badges.FirstRebirth)
end

function Badges.area(player: Player, zoneIndex: number)
	award(player, Config.Badges.Areas[zoneIndex])
end

-- Call after a pet is discovered: awards the Secret pet and full Index badges when they apply.
function Badges.discovered(player: Player, petId: string, index: { [string]: boolean })
	local pet = Pets[petId]
	if pet and pet.Rarity == "Secret" then
		award(player, Config.Badges.SecretPet)
	end
	-- Only hatchable pets count; exclusives like the paid Starter Pup must never be required.
	for id, def in Pets do
		if not def.Exclusive and not index[id] then
			return
		end
	end
	award(player, Config.Badges.FullIndex)
end

function Badges.Init()
	DataService.onLoaded(function(profile)
		tried[profile.Player] = {}
	end)
	DataService.onRelease(function(profile)
		tried[profile.Player] = nil
	end)
end

function Badges.Start() end

return Badges
