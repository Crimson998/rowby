--!strict
--[[
	ViewportFrame helpers for showing pets and eggs in the UI.
]]

local Viewport = {}

function Viewport.new(props: { [string]: any }): ViewportFrame
	local frame = Instance.new("ViewportFrame")
	frame.BackgroundTransparency = 1
	frame.Ambient = Color3.fromRGB(170, 170, 185)
	frame.LightColor = Color3.fromRGB(255, 255, 255)
	frame.LightDirection = Vector3.new(-0.4, -1, -0.6)
	for key, value in props do
		if key ~= "Parent" then
			(frame :: any)[key] = value
		end
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 38
	camera.Parent = frame
	frame.CurrentCamera = camera
	frame.Parent = props.Parent
	return frame
end

-- Replaces whatever the viewport shows with `model`, framed from the front.
function Viewport.show(frame: ViewportFrame, model: Model, distance: number?)
	for _, child in frame:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end
	model:PivotTo(CFrame.new())
	model.Parent = frame
	local camera = frame.CurrentCamera
	if camera then
		local eye = Vector3.new(1.4, 1.1, -(distance or 5.6))
		camera.CFrame = CFrame.lookAt(eye, Vector3.new(0, 0.25, 0))
	end
end

-- Rotates the model shown in a viewport around its vertical axis.
function Viewport.spin(frame: ViewportFrame, angle: number)
	local model = frame:FindFirstChildOfClass("Model")
	if model then
		model:PivotTo(CFrame.Angles(0, angle, 0))
	end
end

return Viewport
