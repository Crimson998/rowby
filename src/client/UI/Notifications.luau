--[[
	Toast messages at the top of the screen, plus the big announcement banner.
]]

local Sound = require(script.Parent.Parent.Sound)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local Notifications = {}

local MAX_TOASTS = 4
local KIND_COLORS = {
	Info = Theme.Colors.Blue,
	Success = Theme.Colors.Green,
	Error = Theme.Colors.Red,
	Reward = Theme.Colors.Purple,
}

local container: Frame
local banner: TextLabel
local bannerToken = 0
local toastCount = 0

function Notifications.build(screen: ScreenGui)
	container = Util.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(460, 220),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = screen,
	}, { Util.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center) })
	Util.autoScale(container)

	banner = Util.label({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(760, 70),
		Text = "",
		Visible = false,
		ZIndex = 12,
		Parent = screen,
	})
	Util.autoScale(banner)
end

function Notifications.show(text: string, kind: string?)
	local color = KIND_COLORS[kind or "Info"] or Theme.Colors.Blue
	toastCount += 1
	local toast = Util.new("Frame", {
		Name = "Toast",
		LayoutOrder = toastCount,
		Size = UDim2.fromOffset(440, 42),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.05,
		Parent = container,
	}, { Util.corner(21), Util.stroke(nil, 3) })
	local label = Util.label({
		Size = UDim2.new(1, -24, 1, -10),
		Position = UDim2.fromOffset(12, 5),
		Text = text,
		Parent = toast,
	})

	local toasts = {}
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > MAX_TOASTS then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end

	if kind == "Error" then
		Sound.play("Error", 0.7, 0.4)
	elseif kind == "Reward" or kind == "Success" then
		Sound.play("Coin", 1.2, 0.5)
	end

	task.delay(3.5, function()
		if toast.Parent then
			Util.tween(toast, 0.3, { BackgroundTransparency = 1 })
			Util.tween(label, 0.3, { TextTransparency = 1 })
			task.wait(0.3)
			toast:Destroy()
		end
	end)
end

-- Big centered text for special moments (rare hatches, rebirths, new areas).
function Notifications.banner(text: string, color: Color3?, seconds: number?)
	bannerToken += 1
	local token = bannerToken
	banner.Text = text
	banner.TextColor3 = color or Theme.Colors.Gold
	banner.TextTransparency = 1
	banner.Visible = true
	local scale = banner:FindFirstChild("AutoScale") :: UIScale
	scale.Scale = Util.getScale() * 0.6
	Util.tween(scale, 0.35, { Scale = Util.getScale() }, Enum.EasingStyle.Back)
	Util.tween(banner, 0.2, { TextTransparency = 0 })
	task.delay(seconds or 3, function()
		if token == bannerToken then
			Util.tween(banner, 0.4, { TextTransparency = 1 })
			task.wait(0.4)
			if token == bannerToken then
				banner.Visible = false
			end
		end
	end)
end

return Notifications
