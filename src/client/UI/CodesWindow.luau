local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)

local Sound = require(script.Parent.Parent.Sound)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Windows = require(script.Parent.Windows)

local CodesWindow = {}

function CodesWindow.build()
	local body = Windows.create("Codes", "🎫 Codes", Theme.Colors.Gray, Vector2.new(460, 290))

	Util.label({
		Size = UDim2.new(1, 0, 0, 24),
		Text = "Join the group for new codes! Psst… try RELEASE",
		TextColor3 = Theme.Colors.SubText,
		Parent = body,
	})
	local input = Util.new("TextBox", {
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = Theme.Colors.Panel,
		Font = Theme.Font,
		PlaceholderText = "Enter code…",
		PlaceholderColor3 = Theme.Colors.SubText,
		Text = "",
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
		ClearTextOnFocus = false,
		Parent = body,
	}, { Util.corner(12), Util.stroke(nil, 3), Util.padding(8) })
	local result =
		Util.label({ Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 28), Text = "", Parent = body })

	local busy = false
	local function redeem()
		if busy or input.Text == "" then
			return
		end
		busy = true
		local ok, success, message = pcall(function()
			return Net.func("RedeemCode"):InvokeServer(input.Text)
		end)
		busy = false
		if not ok then
			success, message = false, "Try again in a moment."
		end
		result.Text = message or ""
		result.TextColor3 = if success then Theme.Colors.Green else Theme.Colors.Red
		if success then
			Sound.play("Coin", 1.2, 0.6)
			input.Text = ""
		end
	end

	Util.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(220, 56),
		Text = "Redeem",
		Color = Theme.Colors.Green,
		Parent = body,
	}, redeem)
	input.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			redeem()
		end
	end)
end

return CodesWindow
