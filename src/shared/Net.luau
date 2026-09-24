--[[
	Remote registry. The server creates every remote up front; clients wait for them.

	Client -> Server
		Tap()                         one tap (rate limited on the server)
		Action(name, ...)             every other request, see server init for the list
		RedeemCode(code) -> (ok, msg) RemoteFunction
	Server -> Client
		Sync(payload)                 partial state: { Data = {...}, Session = {...}, Full = bool? }
		Notify(text, kind)            toast message
		Hatched(eggId, results)       hatch animation
		Announce(text, color)         server-wide rare hatch / milestone
		OrbCollected(position, kind, amount)
		Effect(name, ...)             one-off client effects (rebirth, zone unlock)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = { "Tap", "Action", "Sync", "Notify", "Hatched", "Announce", "OrbCollected", "Effect" }
local FUNCTIONS = { "RedeemCode" }

local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = "Remotes"

local folder: Folder

if IS_SERVER then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local Net = {}

function Net.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net
