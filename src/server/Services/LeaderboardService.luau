--[[
	Player-list leaderstats plus the two global leaderboards in the spawn plaza.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)

local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

local LeaderboardService = {}

local REFRESH_SECONDS = 120

local BOARDS = {
	{
		Board = "RebirthBoard",
		Store = "LB_Rebirths_v1",
		Value = function(data)
			return data.Rebirths
		end,
	},
	{
		Board = "EggBoard",
		Store = "LB_Eggs_v1",
		Value = function(data)
			return data.Stats.EggsHatched
		end,
	},
}

local nameCache: { [number]: string } = {}
-- Last value written per board and player, so unchanged scores don't use DataStore budget.
local written: { [string]: { [number]: number } } = {}

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local resolved = if ok and name then name else "Player"
	nameCache[userId] = resolved
	return resolved
end

local function createLeaderstats(profile)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = profile.Data.Rebirths
	rebirths.Parent = folder
	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Value = Format.number(profile.Data.Coins)
	coins.Parent = folder
	folder.Parent = profile.Player
end

local function refreshBoards()
	if DataService.isMock() then
		return
	end
	for _, board in BOARDS do
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, board.Store)
		if not ok then
			continue
		end
		written[board.Store] = written[board.Store] or {}
		local last = written[board.Store]
		for _, profile in DataService.list() do
			local userId = profile.Player.UserId
			local value = math.floor(board.Value(profile.Data))
			if last[userId] ~= value then
				local saved = pcall(function()
					store:SetAsync(tostring(userId), value)
				end)
				if saved then
					last[userId] = value
				end
			end
		end
		local pageOk, page = pcall(function()
			return store:GetSortedAsync(false, 10):GetCurrentPage()
		end)
		local rows = WorldService.Boards[board.Board]
		if pageOk and rows then
			for index, row in rows do
				local entry = page[index]
				if entry then
					row.Text = string.format(
						"%d. %s — %s",
						index,
						nameFor(tonumber(entry.key) or 0),
						Format.number(entry.value)
					)
				else
					row.Text = index .. ". ..."
				end
			end
		end
	end
end

function LeaderboardService.Init()
	DataService.onLoaded(createLeaderstats)
	DataService.onRelease(function(profile)
		for _, values in written do
			values[profile.Player.UserId] = nil
		end
	end)
end

function LeaderboardService.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			for player, profile in DataService.all() do
				local stats = player:FindFirstChild("leaderstats")
				if stats then
					local coins = stats:FindFirstChild("Coins") :: StringValue?
					local rebirths = stats:FindFirstChild("Rebirths") :: IntValue?
					if coins then
						coins.Value = Format.number(profile.Data.Coins)
					end
					if rebirths then
						rebirths.Value = profile.Data.Rebirths
					end
				end
			end
		end
	end)

	task.spawn(function()
		task.wait(10)
		while true do
			refreshBoards()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return LeaderboardService
