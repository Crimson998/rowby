--[[
	Small helpers for building UI in code: instance creation, styling, tweens, bouncy buttons
	and a global scale that adapts the whole HUD to phone, tablet and desktop screens.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Util = {}

function Util.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Util.corner(radius: number?): UICorner
	return Util.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Util.stroke(color: Color3?, thickness: number?): UIStroke
	return Util.new("UIStroke", {
		Name = "Border",
		Color = color or Theme.Colors.Stroke,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Util.textStroke(thickness: number?): UIStroke
	return Util.new("UIStroke", {
		Name = "TextStroke",
		Color = Theme.Colors.Stroke,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function Util.padding(pixels: number): UIPadding
	local amount = UDim.new(0, pixels)
	return Util.new(
		"UIPadding",
		{ PaddingTop = amount, PaddingBottom = amount, PaddingLeft = amount, PaddingRight = amount }
	)
end

function Util.list(
	direction: Enum.FillDirection?,
	padding: number?,
	horizontal: Enum.HorizontalAlignment?,
	vertical: Enum.VerticalAlignment?
): UIListLayout
	return Util.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 8),
		HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vertical or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Util.gradient(top: Color3, bottom: Color3): UIGradient
	return Util.new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 })
end

function Util.tween(
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

function Util.label(props: { [string]: any }): TextLabel
	local label = Util.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
	}, { Util.textStroke() })
	for key, value in props do
		if key ~= "Parent" then
			(label :: any)[key] = value
		end
	end
	label.Parent = props.Parent
	return label
end

-- A chunky button that squishes when pressed. Returns the button; set .Text for its label.
function Util.button(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local color = props.Color or Theme.Colors.Blue
	local button = Util.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Font = Theme.Font,
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
		Text = "",
	}, {
		Util.corner(props.CornerRadius or 12),
		Util.stroke(),
		Util.textStroke(),
		Util.new("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
	})
	local press = Util.new("UIScale", { Name = "Press", Parent = button })
	for key, value in props do
		if key ~= "Parent" and key ~= "Color" and key ~= "CornerRadius" then
			(button :: any)[key] = value
		end
	end
	button.MouseEnter:Connect(function()
		Util.tween(press, 0.1, { Scale = 1.05 })
	end)
	button.MouseLeave:Connect(function()
		Util.tween(press, 0.1, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		Util.tween(press, 0.06, { Scale = 0.92 })
	end)
	button.MouseButton1Up:Connect(function()
		Util.tween(press, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	button.Parent = props.Parent
	return button
end

-- Progress bar; returns the bar and a setter taking (fraction, text).
function Util.bar(props: { [string]: any }): (Frame, (number, string?) -> ())
	local bar = Util.new("Frame", {
		BackgroundColor3 = Theme.Colors.PanelLight,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ClipsDescendants = true,
		Parent = props.Parent,
	}, { Util.corner(props.CornerRadius or 10), Util.stroke(nil, 2) })
	local fill = Util.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = props.Color or Theme.Colors.Green,
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	}, { Util.corner(props.CornerRadius or 10) })
	local text = Util.label({
		Size = UDim2.fromScale(1, 0.8),
		Position = UDim2.fromScale(0, 0.1),
		Text = "",
		ZIndex = 2,
		Parent = bar,
	})
	local function set(fraction: number, label: string?)
		fraction = math.clamp(fraction, 0, 1)
		Util.tween(fill, 0.2, { Size = UDim2.fromScale(fraction, 1) })
		text.Text = label or ""
	end
	return bar, set
end

-- Global HUD scale -------------------------------------------------------------------------

local scaled: { UIScale } = {}
local currentScale = 1

local function computeScale(): number
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.clamp(math.min(viewport.X / 1150, viewport.Y / 720), 0.5, 1.15)
end

function Util.getScale(): number
	return currentScale
end

function Util.autoScale(guiObject: GuiObject): UIScale
	local scale = Util.new("UIScale", { Name = "AutoScale", Scale = currentScale, Parent = guiObject })
	table.insert(scaled, scale)
	return scale
end

function Util.startAutoScale()
	local function update()
		currentScale = computeScale()
		for _, scale in scaled do
			scale.Scale = currentScale
		end
	end
	update()
	local function watchCamera()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
end

return Util
