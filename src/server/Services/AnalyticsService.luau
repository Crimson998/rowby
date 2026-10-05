--!strict
--[[
	Roblox analytics: a first-session funnel (join, first hatch, area 2, first rebirth) and
	economy events for coin sinks and gem sources, so prices and pacing can be tuned from real
	data. Every call is wrapped in pcall; analytics must never break gameplay.
]]

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")

local DataService = require(script.Parent.DataService)

local Analytics = {}

local FUNNEL = "FirstSession"
local STEPS = { Join = 1, FirstHatch = 2, Area2 = 3, FirstRebirth = 4 }

-- Funnel session ids are per player and per visit; steps are only logged once each.
local sessions: { [Player]: { Id: string, Done: { [string]: boolean } } } = {}

function Analytics.funnel(player: Player, step: string)
	local number = STEPS[step]
	local session = sessions[player]
	if not number or not session or session.Done[step] then
		return
	end
	session.Done[step] = true
	local service = AnalyticsService :: any
	pcall(function()
		service:LogFunnelStepEvent(player, FUNNEL, session.Id, number, step)
	end)
end

local function economy(player: Player, flow: any, currency: string, balance: number, amount: number, sku: string)
	local service = AnalyticsService :: any
	pcall(function()
		-- Roblox's order is amount, then the balance after the transaction.
		service:LogEconomyEvent(
			player,
			flow,
			currency,
			math.floor(amount),
			math.floor(balance),
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			sku
		)
	end)
end

-- Coins spent on something (eggs, upgrades, areas, rebirth); balance is what is left after.
function Analytics.sink(player: Player, currency: string, balance: number, amount: number, sku: string)
	if amount > 0 then
		economy(player, Enum.AnalyticsEconomyFlowType.Sink, currency, balance, amount, sku)
	end
end

-- Gems (or other currency) earned; balance is the new total.
function Analytics.source(player: Player, currency: string, balance: number, amount: number, sku: string)
	if amount > 0 then
		economy(player, Enum.AnalyticsEconomyFlowType.Source, currency, balance, amount, sku)
	end
end

function Analytics.Init()
	DataService.onLoaded(function(profile)
		sessions[profile.Player] = { Id = HttpService:GenerateGUID(false), Done = {} }
		Analytics.funnel(profile.Player, "Join")
	end)
	DataService.onRelease(function(profile)
		sessions[profile.Player] = nil
	end)
end

function Analytics.Start() end

return Analytics
