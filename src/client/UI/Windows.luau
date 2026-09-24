--[[
	Pop-up windows. One is open at a time; opening another closes the current one.
]]

local Sound = require(script.Parent.Parent.Sound)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

type Entry = { Frame: Frame, Scale: UIScale, OnOpen: { () -> () } }

local Windows = {}

local registry: { [string]: Entry } = {}
local openName: string? = nil
local screen: ScreenGui

function Windows.init(gui: ScreenGui)
	screen = gui
end

-- Creates a window and returns its body frame (where content goes).
function Windows.create(name: string, title: string, color: Color3, size: Vector2): Frame
	local frame = Util.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Theme.Colors.Background,
		Visible = false,
		ZIndex = 5,
		Parent = screen,
	}, { Util.corner(20), Util.stroke(Theme.Colors.Stroke, 4) })
	local scale = Util.autoScale(frame)

	local header = Util.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = color,
		Parent = frame,
	}, { Util.corner(20), Util.gradient(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)) })
	-- Square off the header's bottom corners.
	Util.new("Frame", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -20),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = header,
	})
	Util.label({
		Size = UDim2.new(1, -140, 0, 40),
		Position = UDim2.fromOffset(20, 9),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = header,
	})
	Util.button({
		Text = "X",
		Color = Theme.Colors.Red,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(44, 42),
		ZIndex = 3,
		Parent = header,
	}, function()
		Windows.close(name)
	end)

	local body = Util.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 70),
		Size = UDim2.new(1, -32, 1, -86),
		Parent = frame,
	})

	registry[name] = { Frame = frame, Scale = scale, OnOpen = {} }
	return body
end

function Windows.onOpen(name: string, handler: () -> ())
	table.insert(registry[name].OnOpen, handler)
end

function Windows.isOpen(name: string): boolean
	return openName == name
end

function Windows.close(name: string)
	local entry = registry[name]
	if not entry then
		return
	end
	entry.Frame.Visible = false
	if openName == name then
		openName = nil
	end
end

function Windows.closeAll()
	if openName then
		Windows.close(openName)
	end
end

function Windows.open(name: string)
	local entry = registry[name]
	if not entry or openName == name then
		return
	end
	Windows.closeAll()
	openName = name
	entry.Frame.Visible = true
	local target = Util.getScale()
	entry.Scale.Scale = target * 0.85
	Util.tween(entry.Scale, 0.22, { Scale = target }, Enum.EasingStyle.Back)
	Sound.play("Click", 1.1, 0.4)
	for _, handler in entry.OnOpen do
		task.spawn(handler)
	end
end

function Windows.toggle(name: string)
	if openName == name then
		Windows.close(name)
	else
		Windows.open(name)
	end
end

return Windows
