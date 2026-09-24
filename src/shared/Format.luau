local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trim(text: string): string
	if string.find(text, "%.") then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text
end

-- 950 -> "950", 12_345 -> "12.3K", 4_500_000 -> "4.5M"
function Format.number(value: number): string
	if value ~= value or value == math.huge then
		return "∞"
	end
	local sign = if value < 0 then "-" else ""
	value = math.abs(value)
	if value < 1000 then
		if value < 10 and value % 1 ~= 0 then
			return sign .. trim(string.format("%.2f", value))
		elseif value % 1 ~= 0 then
			return sign .. trim(string.format("%.1f", value))
		end
		return sign .. tostring(math.floor(value))
	end
	local tier = 1
	while value >= 1000 and tier < #SUFFIXES do
		value /= 1000
		tier += 1
	end
	if value >= 1000 then
		return sign .. string.format("%.2e", value * 1000 ^ (tier - 1))
	end
	local text
	if value < 10 then
		text = string.format("%.2f", value)
	elseif value < 100 then
		text = string.format("%.1f", value)
	else
		text = string.format("%.0f", value)
	end
	return sign .. trim(text) .. SUFFIXES[tier]
end

-- 1234567 -> "1,234,567"
function Format.commas(value: number): string
	local text = tostring(math.floor(value))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	return (string.gsub(formatted, "^(-?),", "%1"))
end

-- 65 -> "1:05", 3725 -> "1:02:05", 90000 -> "1d 1h"
function Format.time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days = seconds // 86400
	local hours = (seconds % 86400) // 3600
	local minutes = (seconds % 3600) // 60
	local secs = seconds % 60
	if days > 0 then
		return string.format("%dd %dh", days, hours)
	elseif hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

-- 0.0001 -> "0.01%", 0.62 -> "62%"
function Format.chance(fraction: number): string
	local percent = fraction * 100
	if percent >= 10 then
		return trim(string.format("%.1f", percent)) .. "%"
	elseif percent >= 1 then
		return trim(string.format("%.2f", percent)) .. "%"
	elseif percent >= 0.01 then
		return trim(string.format("%.3f", percent)) .. "%"
	end
	return trim(string.format("%.5f", percent)) .. "%"
end

function Format.multiplier(value: number): string
	return "x" .. Format.number(value)
end

return Format
