--!strict
--[[
	Reveal effects for the hatch overlay, scaled to how good the pull is. Built from plain UI
	(particles don't render inside ViewportFrames), so no uploaded textures are needed.

	- Every pet: a soft glow in its rarity colour (or tier colour).
	- Rare and better, or any higher tier: spinning light rays.
	- Legendary and better, or Diamond and better: a confetti burst.
	- Golden: twinkling gold stars. Diamond: white shards. Emerald: lucky clovers floating up.
	  Void: purple sparks orbiting the pet.

	Low-detail mode keeps only the glow and rays.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Pets = require(Shared.Pets)

local State = require(script.Parent.Parent.State)
local Util = require(script.Parent.Util)

local HatchEffects = {}

export type Result = { Id: string, Tier: number }
export type Effect = {
	-- How big the moment is: rarity rank (1 Common … 7 Secret) plus 2 per tier above Normal.
	Excitement: number,
	-- The effect's main colour, for the screen flash.
	Color: Color3,
	-- Call every frame with the seconds since the reveal.
	Update: (elapsed: number) -> (),
}

local CENTER = UDim2.fromScale(0.5, 0.5)
local RARE = 3
local LEGENDARY = 5

local rng = Random.new()

local function lowDetail(): boolean
	local settings = State.Data.Settings
	return settings ~= nil and settings.LowDetail == true
end

local function circle(parent: Instance, size: number, color: Color3, transparency: number, zIndex: number): Frame
	return Util.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = CENTER,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Parent = parent,
	}, { Util.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
end

-- A bar through the centre that fades out towards both ends; several at different angles
-- make a starburst.
local function ray(parent: Instance, length: number, width: number, color: Color3): Frame
	return Util.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = CENTER,
		Size = UDim2.fromOffset(width, length),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = parent,
	}, {
		Util.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
end

-- Shoots small pieces out from the centre; they spin, drift and fade away.
local function burst(
	parent: Instance,
	count: number,
	colors: { Color3 },
	size: Vector2,
	distance: NumberRange,
	seconds: number,
	text: string?
)
	for _ = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local reach = rng:NextNumber(distance.Min, distance.Max)
		local target = UDim2.new(0.5, math.cos(angle) * reach, 0.5, math.sin(angle) * reach + reach * 0.25)
		local color = colors[rng:NextInteger(1, #colors)]
		local piece: GuiObject
		if text then
			piece = Util.label({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = CENTER,
				Size = UDim2.fromOffset(size.X, size.Y),
				Text = text,
				TextColor3 = color,
				Rotation = rng:NextNumber(-30, 30),
				ZIndex = 3,
				Parent = parent,
			})
		else
			piece = Util.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = CENTER,
				Size = UDim2.fromOffset(size.X, size.Y),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				Rotation = rng:NextNumber(0, 360),
				ZIndex = 3,
				Parent = parent,
			})
		end
		local goal: { [string]: any } = { Position = target, Rotation = piece.Rotation + rng:NextNumber(-270, 270) }
		if piece:IsA("TextLabel") then
			goal.TextTransparency = 1
		else
			goal.BackgroundTransparency = 1
		end
		Util.tween(piece, seconds * rng:NextNumber(0.8, 1.2), goal, Enum.EasingStyle.Quart)
	end
end

-- Builds the reveal effect for one hatch result. `back` and `front` are frames the size of the
-- pet's viewport, placed behind and in front of it: glows and rays go behind the pet, flying
-- pieces in front.
function HatchEffects.create(back: Frame, front: Frame, result: Result): Effect
	local pet = Pets[result.Id]
	local rank = table.find(Config.RarityOrder, pet.Rarity) or 1
	local tierIndex = math.clamp(result.Tier or 1, 1, #Config.Tiers)
	local tier = Config.Tiers[tierIndex]
	local excitement = rank + (tierIndex - 1) * 2
	local rarityColor = Config.Rarities[pet.Rarity].Color
	-- Void's own colour is nearly black, so it glows in its accent instead.
	local color = if tierIndex == 1
		then rarityColor
		elseif tier.Name == "Void" then tier.Accent :: Color3
		else tier.Color :: Color3
	local simple = lowDetail()
	local updates: { (number) -> () } = {}

	-- Glow: three soft circles that breathe.
	local glows = {
		circle(back, 170, color, 0.55, 0),
		circle(back, 230, color, 0.78, 0),
		circle(back, 300, color, 0.9, 0),
	}
	table.insert(updates, function(t)
		local pulse = 1 + math.sin(t * 4) * 0.06
		for index, glow in glows do
			local base = 110 + index * 60
			glow.Size = UDim2.fromOffset(base * pulse, base * pulse)
		end
	end)

	-- Light rays for Rare+ pets or any higher tier.
	if rank >= RARE or tierIndex > 1 then
		local count = if excitement >= LEGENDARY + 2 then 8 elseif excitement >= LEGENDARY then 6 else 4
		local length = if excitement >= LEGENDARY then 420 else 340
		local rays = {}
		for index = 1, count do
			rays[index] = ray(back, length, if excitement >= LEGENDARY then 30 else 22, color)
		end
		local speed = if excitement >= LEGENDARY then 40 else 25
		table.insert(updates, function(t)
			for index, bar in rays do
				bar.Rotation = (index - 1) * (180 / #rays) + t * speed
			end
		end)
	end

	if simple then
		return {
			Excitement = excitement,
			Color = color,
			Update = function(t)
				for _, update in updates do
					update(t)
				end
			end,
		}
	end

	-- Confetti for Legendary+ pets, Diamond+ tiers, or anything that adds up to as exciting.
	if excitement >= LEGENDARY then
		local count = math.clamp(14 + (excitement - LEGENDARY) * 6, 14, 44)
		burst(
			front,
			count,
			{ color, rarityColor, Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 215, 80) },
			Vector2.new(8, 14),
			NumberRange.new(120, 230),
			1.2
		)
	end

	if tier.Name == "Golden" then
		-- Twinkling gold stars around the pet.
		local stars = {}
		for index = 1, 7 do
			local angle = (index / 7) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local reach = rng:NextNumber(85, 120)
			stars[index] = Util.label({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, math.cos(angle) * reach, 0.5, math.sin(angle) * reach),
				Size = UDim2.fromOffset(28, 28),
				Text = "✦",
				TextColor3 = tier.Accent :: Color3,
				ZIndex = 3,
				Parent = front,
			})
		end
		table.insert(updates, function(t)
			for index, star in stars do
				local twinkle = (math.sin(t * 6 + index * 1.7) + 1) / 2
				star.TextTransparency = 0.7 - twinkle * 0.7
				star.Size = UDim2.fromOffset(18 + twinkle * 16, 18 + twinkle * 16)
			end
		end)
	elseif tier.Name == "Diamond" then
		-- Crystal shards fly out fast.
		burst(
			front,
			16,
			{ Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 240, 255) },
			Vector2.new(5, 24),
			NumberRange.new(150, 260),
			0.8
		)
	elseif tier.Name == "Emerald" then
		-- Lucky clovers float up and fade.
		for index = 1, 8 do
			local clover = Util.label({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, rng:NextNumber(-100, 100), 0.5, rng:NextNumber(10, 90)),
				Size = UDim2.fromOffset(30, 30),
				Text = "🍀",
				ZIndex = 3,
				Parent = front,
			})
			task.delay(index * 0.12, function()
				if clover.Parent then
					Util.tween(clover, 1.6, {
						Position = clover.Position - UDim2.fromOffset(0, rng:NextNumber(120, 190)),
						TextTransparency = 1,
						Rotation = rng:NextNumber(-60, 60),
					}, Enum.EasingStyle.Sine)
				end
			end)
		end
	elseif tier.Name == "Void" then
		-- Purple sparks orbiting the pet on a tilted ring.
		local sparks = {}
		for index = 1, 12 do
			sparks[index] = circle(front, if index % 3 == 0 then 14 else 9, color, 0, 3)
		end
		table.insert(updates, function(t)
			for index, spark in sparks do
				local angle = t * 2.4 + index * (math.pi * 2 / #sparks)
				spark.Position = UDim2.new(0.5, math.cos(angle) * 125, 0.5, math.sin(angle) * 45)
				-- Sparks on the far side move behind the pet and dim, so the ring goes around it.
				local behind = math.sin(angle) < 0
				spark.BackgroundTransparency = if behind then 0.5 else 0
				local layer = if behind then back else front
				if spark.Parent ~= layer then
					spark.Parent = layer
				end
			end
		end)
	end

	return {
		Excitement = excitement,
		Color = color,
		Update = function(t)
			for _, update in updates do
				update(t)
			end
		end,
	}
end

return HatchEffects
