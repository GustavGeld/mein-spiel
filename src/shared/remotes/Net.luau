--!strict
-- Net-Wrapper. Server erstellt Remotes lazy, Client wartet darauf.
-- Whitelist via Definitions verhindert Tippfehler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Definitions = require(script.Parent.Definitions)

local Net = {}

local FOLDER_NAME = "Remotes"
local FUNC_FOLDER_NAME = "Functions"
local EVENT_FOLDER_NAME = "Events"

local function getRoot(): Folder
	local root = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if root then return root end
	if RunService:IsServer() then
		root = Instance.new("Folder")
		root.Name = FOLDER_NAME
		local fns = Instance.new("Folder")
		fns.Name = FUNC_FOLDER_NAME
		fns.Parent = root
		local evs = Instance.new("Folder")
		evs.Name = EVENT_FOLDER_NAME
		evs.Parent = root
		root.Parent = ReplicatedStorage
		return root
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local function getOrCreate(parent: Folder, name: string, className: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then return existing end
	if RunService:IsServer() then
		local inst = Instance.new(className)
		inst.Name = name
		inst.Parent = parent
		return inst
	end
	return parent:WaitForChild(name)
end

function Net:Function(name: string): RemoteFunction
	assert(Definitions.Functions[name], "Unknown RemoteFunction: " .. name)
	local root = getRoot()
	local fns = root:FindFirstChild(FUNC_FOLDER_NAME) or root:WaitForChild(FUNC_FOLDER_NAME)
	return getOrCreate(fns :: Folder, name, "RemoteFunction") :: RemoteFunction
end

function Net:Event(name: string): RemoteEvent
	assert(Definitions.Events[name], "Unknown RemoteEvent: " .. name)
	local root = getRoot()
	local evs = root:FindFirstChild(EVENT_FOLDER_NAME) or root:WaitForChild(EVENT_FOLDER_NAME)
	return getOrCreate(evs :: Folder, name, "RemoteEvent") :: RemoteEvent
end

return Net
