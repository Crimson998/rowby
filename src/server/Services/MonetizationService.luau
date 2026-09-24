--[[
	Game passes, developer products and the purchase receipt handler.

	ProcessReceipt follows Roblox's recommended pattern: a receipt is only reported as granted
	after the grant has been saved, and receipt ids are recorded so a retried receipt can never
	be granted twice.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared.Products)
local Rewards = require(Shared.Rewards)

local Actions = require(script.Parent.Parent.Actions)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PetService = require(script.Parent.PetService)

local MonetizationService = {}

local MAX_RECEIPTS = 100

local productById: { [number]: Products.DevProduct } = {}
local passById: { [number]: Products.GamePass } = {}

local function applyPass(profile, key: string)
	local session = profile.Session
	session.Passes[key] = true
	DataService.change(profile, "Session.Passes")
	if key == "VIP" then
		profile.Player:SetAttribute("VIP", true)
	end
	if key == "VIP" or key == "ExtraPets" then
		PetService.equipBest(profile)
	end
	if key == "AutoTap" then
		session.AutoTap = true
		DataService.change(profile, "Session.AutoTap")
	end
end

local function grantProduct(profile, product: Products.DevProduct)
	DataService.grantReward(profile, product.Reward)
	if product.Reward.Pet then
		PetService.givePet(profile, product.Reward.Pet, false)
		PetService.equipBest(profile)
	end
	if product.OneTime then
		profile.Data.OneTime[product.Key] = true
		DataService.change(profile, "OneTime")
	end
	EconomyService.applyWalkSpeed(profile)
end

local function thank(profile, name: string, reward: Products.Reward?)
	local detail = if reward then "  " .. Rewards.describe(reward, profile.Data, profile.Session) else ""
	DataService.notify(profile.Player, "💖 Thanks for buying " .. name .. "!" .. detail, "Success")
end

local function blockedByPolicy(profile, item: { RandomItemRelated: boolean? }): boolean
	if item.RandomItemRelated and profile.Session.RandomItemsRestricted then
		DataService.notify(profile.Player, "This item isn't available in your region.", "Error")
		return true
	end
	return false
end

function MonetizationService.promptPass(profile, key: string)
	local pass = Products.PassByKey[key]
	if not pass or profile.Session.Passes[key] or blockedByPolicy(profile, pass) then
		return
	end
	if pass.Id == 0 then
		if RunService:IsStudio() then
			applyPass(profile, key)
			thank(profile, pass.Name .. " (Studio test)", nil)
		else
			DataService.notify(profile.Player, pass.Name .. " isn't on sale yet!", "Info")
		end
		return
	end
	MarketplaceService:PromptGamePassPurchase(profile.Player, pass.Id)
end

function MonetizationService.promptProduct(profile, key: string)
	local product = Products.ProductByKey[key]
	if not product or blockedByPolicy(profile, product) then
		return
	end
	if product.OneTime and profile.Data.OneTime[key] then
		DataService.notify(profile.Player, "You already own the " .. product.Name .. "!", "Info")
		return
	end
	if product.Id == 0 then
		if RunService:IsStudio() then
			grantProduct(profile, product)
			thank(profile, product.Name .. " (Studio test)", product.Reward)
		else
			DataService.notify(profile.Player, product.Name .. " isn't on sale yet!", "Info")
		end
		return
	end
	MarketplaceService:PromptProductPurchase(profile.Player, product.Id)
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.waitFor(player, 15)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = profile.Data

	if table.find(data.Purchases, receipt.PurchaseId) then
		-- Already granted earlier; make sure that grant is saved before confirming.
		return if DataService.save(profile)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local product = productById[receipt.ProductId]
	if not product then
		warn("[Monetization] Unknown product id " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, err = pcall(grantProduct, profile, product)
	if not ok then
		warn("[Monetization] Grant failed: " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(data.Purchases, receipt.PurchaseId)
	while #data.Purchases > MAX_RECEIPTS do
		table.remove(data.Purchases, 1)
	end
	data.Stats.RobuxSpent += receipt.CurrencySpent or 0

	if not DataService.save(profile) then
		-- The receipt id is recorded in memory, so the retry won't grant it a second time.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	thank(profile, product.Name, product.Reward)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function loadPasses(profile)
	local player = profile.Player
	local pending = 0
	for _, pass in Products.GamePasses do
		if pass.Id == 0 then
			continue
		end
		pending += 1
		task.spawn(function()
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and owns then
				applyPass(profile, pass.Key)
			end
			pending -= 1
		end)
	end
	local deadline = os.clock() + 10
	while pending > 0 and os.clock() < deadline do
		task.wait()
	end
end

local function loadPolicy(profile)
	local ok, policy = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, profile.Player)
	-- If the policy can't be read, assume the strictest setting.
	profile.Session.RandomItemsRestricted = not ok or policy.ArePaidRandomItemsRestricted == true
	DataService.change(profile, "Session.RandomItemsRestricted")
end

function MonetizationService.Init()
	for _, product in Products.DevProducts do
		if product.Id ~= 0 then
			productById[product.Id] = product
		end
	end
	for _, pass in Products.GamePasses do
		if pass.Id ~= 0 then
			passById[pass.Id] = pass
		end
	end

	DataService.onLoaded(function(profile)
		loadPolicy(profile)
		loadPasses(profile)
	end)
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = passById[passId]
		local profile = DataService.get(player)
		if purchased and pass and profile then
			applyPass(profile, pass.Key)
			thank(profile, pass.Name, nil)
		end
	end)

	Players.PlayerMembershipChanged:Connect(function(player)
		local profile = DataService.get(player)
		if profile then
			profile.Session.Premium = player.MembershipType == Enum.MembershipType.Premium
			DataService.change(profile, "Session.Premium")
		end
	end)

	Actions.register("BuyPass", function(profile, key)
		if type(key) == "string" then
			MonetizationService.promptPass(profile, key)
		end
	end)
	Actions.register("BuyProduct", function(profile, key)
		if type(key) == "string" then
			MonetizationService.promptProduct(profile, key)
		end
	end)
end

return MonetizationService
