local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Rewards = require(Shared.Rewards)

local Actions = require(script.Parent.Parent.Actions)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Windows = require(script.Parent.Windows)

local GiftsWindow = {}

local NAME = "Gifts"

function GiftsWindow.build()
	local body = Windows.create(NAME, "🎁 Free Gifts", Theme.Colors.Gold, Vector2.new(640, 420))
	Util.label({
		Size = UDim2.new(1, -160, 0, 24),
		Text = "Gifts unlock the longer you play. Open them all to start a new round!",
		TextColor3 = Theme.Colors.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = body,
	})
	local openAll = Util.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, -4),
		Size = UDim2.fromOffset(150, 32),
		Text = "Open all ready",
		Color = Theme.Colors.Green,
		Parent = body,
	}, function()
		Actions("ClaimAllGifts")
	end)
	local grid = Util.new("Frame", {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		Util.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(140, 144),
			CellPadding = UDim2.fromOffset(12, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local tiles = {}
	for index, gift in Config.Gifts do
		local tile = Util.new("Frame", {
			LayoutOrder = index,
			BackgroundColor3 = Theme.Colors.Panel,
			Parent = grid,
		}, { Util.corner(14), Util.stroke(nil, 3) })
		Util.label({ Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 6), Text = "🎁", Parent = tile })
		local reward = Util.label({
			Size = UDim2.new(1, -10, 0, 40),
			Position = UDim2.fromOffset(5, 48),
			Text = "",
			TextWrapped = true,
			TextColor3 = Theme.Colors.SubText,
			Parent = tile,
		})
		local button = Util.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 40),
			Parent = tile,
		}, function()
			Actions("ClaimGift", index)
		end)
		tiles[index] = { Gift = gift, Reward = reward, Button = button }
	end

	local function refresh()
		local session = State.Session
		local elapsed = workspace:GetServerTimeNow() - session.JoinedAt
		local anyReady = false
		for index, tile in tiles do
			tile.Reward.Text = Rewards.describe(tile.Gift.Reward, State.Data, session)
			local remaining = tile.Gift.Minutes * 60 - elapsed
			if session.GiftsClaimed[index] then
				tile.Button.Text = "✓ Opened"
				tile.Button.BackgroundColor3 = Theme.Colors.Disabled
			elseif remaining <= 0 then
				anyReady = true
				tile.Button.Text = "Open!"
				tile.Button.BackgroundColor3 = Theme.Colors.Green
			else
				tile.Button.Text = Format.time(remaining)
				tile.Button.BackgroundColor3 = Theme.Colors.PanelLight
			end
		end
		openAll.BackgroundColor3 = if anyReady then Theme.Colors.Green else Theme.Colors.Disabled
	end

	State.watch({ "Session.GiftsClaimed", "Session.JoinedAt" }, refresh)
	task.spawn(function()
		while true do
			task.wait(1)
			if Windows.isOpen(NAME) then
				refresh()
			end
		end
	end)
end

return GiftsWindow
