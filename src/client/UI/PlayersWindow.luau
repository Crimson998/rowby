--[[
	👥 Players: everyone in the server. Tap a player to inspect their equipped team and progress.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local Pets = require(Shared.Pets)
local Zones = require(Shared.Zones)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Windows = require(script.Parent.Windows)

local PlayersWindow = {}

local NAME = "Players"

function PlayersWindow.build()
	local body = Windows.create(NAME, "👥 Players", Theme.Colors.Blue, Vector2.new(600, 500))

	local list = Util.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 190),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	}, { Util.list(Enum.FillDirection.Vertical, 6) })

	local detail = Util.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 202),
		Size = UDim2.new(1, 0, 1, -202),
		BackgroundColor3 = Theme.Colors.Panel,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	}, { Util.corner(12), Util.padding(10) })
	local detailText = Util.label({
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = "Tap a player to see their team.",
		TextColor3 = Theme.Colors.SubText,
		TextWrapped = true,
		TextScaled = false,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = detail,
	})

	local selected = 0
	local function show(userId: number)
		selected = userId
		detailText.Text = "Loading…"
		local ok, info = pcall(function()
			return Net.func("InspectPlayer"):InvokeServer(userId)
		end)
		if selected ~= userId then
			return
		end
		if not ok or not info then
			detailText.Text = "That player isn't available."
			return
		end
		local lines = {
			info.Name,
			string.format(
				"🔁 %d rebirths   🗺 %s   🥚 %s hatched   📖 %d/%d pets found",
				info.Rebirths,
				Zones.List[info.HighestZone] and Zones.List[info.HighestZone].Name or "?",
				Format.number(info.EggsHatched),
				info.Discovered,
				info.TotalPets
			),
			"",
			"Equipped team:",
		}
		for _, pet in info.Team do
			local def = Pets[pet.Id]
			local tier = Config.Tiers[pet.Tier]
			if def then
				table.insert(
					lines,
					string.format(
						"• %s%s %s  (Lv %d, %s)",
						if tier and tier.Icon ~= "" then tier.Icon .. " " else "",
						tier and tier.Name or "",
						def.Name,
						pet.Level,
						def.Rarity
					)
				)
			end
		end
		if #info.Team == 0 then
			table.insert(lines, "• No pets equipped")
		end
		detailText.Text = table.concat(lines, "\n")
		detailText.TextColor3 = Theme.Colors.Text
	end

	local function refresh()
		for _, child in list:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		for index, other in Players:GetPlayers() do
			Util.button({
				LayoutOrder = index,
				Size = UDim2.new(1, -12, 0, 40),
				Text = other.DisplayName .. (if other == Players.LocalPlayer then " (you)" else ""),
				Color = Theme.Colors.PanelLight,
				Parent = list,
			}, function()
				show(other.UserId)
			end)
		end
	end

	Windows.onOpen(NAME, function()
		detailText.Text = "Tap a player to see their team."
		detailText.TextColor3 = Theme.Colors.SubText
		selected = 0
		refresh()
	end)
	Players.PlayerAdded:Connect(function()
		if Windows.isOpen(NAME) then
			refresh()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			if Windows.isOpen(NAME) then
				refresh()
			end
		end)
	end)
end

return PlayersWindow
