--[[
	Gold [VIP] chat tag and rare-hatch announcements in chat.
]]

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Chat = {}

local function toHex(color: Color3): string
	return string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255)
end

function Chat.system(text: string, color: Color3?)
	task.spawn(function()
		local channels = TextChatService:WaitForChild("TextChannels", 10)
		local general = channels and channels:WaitForChild("RBXGeneral", 10) :: TextChannel?
		if general then
			local escaped = string.gsub(text, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" })
			general:DisplaySystemMessage(
				string.format('<font color="%s">%s</font>', toHex(color or Color3.new(1, 1, 1)), escaped)
			)
		end
	end)
end

function Chat.start()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local source = message.TextSource
		if not source then
			return nil
		end
		local sender = Players:GetPlayerByUserId(source.UserId)
		if sender and sender:GetAttribute("VIP") then
			local properties = Instance.new("TextChatMessageProperties")
			properties.PrefixText = '<font color="#FFD24A">[VIP]</font> ' .. message.PrefixText
			return properties
		end
		return nil
	end
end

return Chat
