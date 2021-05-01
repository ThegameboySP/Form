local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Maid = require(script.Parent.Parent.Parent.Modules.Maid)

local function callOnReplicated(ref, maid, callback)
	if not ref:IsDescendantOf(workspace) and not ref:IsDescendantOf(ReplicatedStorage) then
		local id
		id = maid:GiveTask(ref.AncestryChanged:Connect(function(_, newParent)
			if newParent ~= workspace and newParent ~= ReplicatedStorage then return end

			maid:Remove(id)
			callback()
		end))
	else
		callback()
	end
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

	local addedRemote = Instance.new("RemoteEvent")
	addedRemote.Name = "ComponentAdded"
	addedRemote.Parent = manFdr

	local removedRemote = Instance.new("RemoteEvent")
	removedRemote.Name = "ComponentRemoved"
	removedRemote.Parent = manFdr

	manFdr.Parent = folder

	return addedRemote, removedRemote
end

return function(man)
	local Replicator = {}
	man.Replicator = Replicator
	local addedRemote, removedRemote = makeInstances(man.Name)

	Replicator.blacklist = setmetatable({}, {__mode = "k"})
	function Replicator:Whitelist(comp)
		assert(type(comp) == "table")
		self.blacklist[comp] = true
	end

	function Replicator:Blacklist(comp)
		assert(type(comp) == "table")
		self.blacklist[comp] = nil
	end

	function Replicator:Clear()
		table.clear(Replicator.blacklist)
	end

	man:On("ComponentAdded", function(ref, comp, config)
		local maid = comp.maid:Add(Maid.new())

		local function onPlayerAdded(player)
			callOnReplicated(ref, maid, function()
				if Replicator.blacklist[comp] then return end
				addedRemote:FireClient(player, ref, comp.BaseName, config)
			end)
		end

		maid:Add(Players.PlayerAdded:Connect(onPlayerAdded))
		for _, player in pairs(Players:GetPlayers()) do
			onPlayerAdded(player)
		end
	end)

	man:On("ComponentRemoved", function(ref, comp)
		removedRemote:FireAllClients(ref, comp.BaseName)
	end)
end