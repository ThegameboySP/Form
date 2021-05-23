local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Maid = require(script.Parent.Parent.Parent.Modules.Maid)
local Utils = require(script.Parent.Utils)

local WEAK_MT = {__mode = "k"}

local function make(className, name, parent)
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function makeInstances(name)
	local folder = ReplicatedStorage:FindFirstChild("CompositeReplication")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "CompositeReplication"
		folder.Parent = ReplicatedStorage
	end

	assert(folder:FindFirstChild(name) == nil)

	local manFdr = Instance.new("Folder")
	manFdr.Name = name

	local added = make("RemoteEvent", "ComponentAdded", manFdr)
	local removed = make("RemoteEvent", "ComponentRemoved", manFdr)
	local stateChanged = make("RemoteEvent", "StateChanged", manFdr)
	local configChanged = make("RemoteEvent", "ConfigChanged", manFdr)
	local finalized = make("RemoteEvent", "Finalized", manFdr)

	manFdr.Parent = folder

	return added, removed, stateChanged, configChanged, finalized
end

return function(man)
	local Replicator = {}
	local added, removed, stateChanged, configChanged, finalized = makeInstances(man.Name)
	local components = setmetatable({}, WEAK_MT)

	man:On("ComponentAdded", function(ref, comp, keywords)
		local maid = comp.externalMaid:Add(Maid.new())
		components[comp] = keywords

		local function replicate()
			for _, player in pairs(Players:GetPlayers()) do
				man:DebugPrint("[Replication]", "Firing", Utils.path(ref, comp.BaseName), "for", player)
				added:FireClient(player, ref, comp.BaseName, comp.state, keywords)
			end
		end

		if not comp.ref:IsDescendantOf(game) then
			local id
			id = maid:GiveTask(ref.AncestryChanged:Connect(function(parent)
				if parent ~= game then return end
				maid:Remove(id)
				replicate()				
			end))
		else
			replicate()
		end

		maid:Add(comp:ConnectSubscribe("", function(delta)
			if not ref:IsDescendantOf(game) then return end

			for _, player in pairs(Players:GetPlayers()) do
				stateChanged:FireClient(player, ref, comp.BaseName, delta)
			end
		end))

		maid:Add(man:On("NewConfig", function()
			local newConfig = comp.config

			for _, player in pairs(Players:GetPlayers()) do
				man:DebugPrint("[Replication]", "Firing config changed for", player, ":", Utils.path(ref, comp.BaseName))
				configChanged:FireClient(player, ref, comp.BaseName, newConfig)
			end
		end))
	end)

	man:On("ComponentRemoved", function(ref, comp)
		removed:FireAllClients(ref, comp.BaseName)
	end)

	local function onPlayerAdded(player)
		man:DebugPrint("[Replication]", "Initializing for", player)

		for comp, keywords in pairs(components) do
			local ref = comp.ref
			if not ref:IsDescendantOf(game) then continue end

			added:FireClient(player, ref, comp.BaseName, comp.state, keywords)
		end

		man:DebugPrint("[Replication]", "Initializing done for", player)
		finalized:FireClient(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in pairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	return Replicator
end