--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)

local actionRemote = Net.event("Action")

-- Sends a request to the server's Actions router, e.g. Actions("BuyUpgrade", "TapPower").
return function(name: string, ...: any)
	actionRemote:FireServer(name, ...)
end
