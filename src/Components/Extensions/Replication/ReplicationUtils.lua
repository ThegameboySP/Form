local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local ReplicationUtils = {}

function ReplicationUtils.onReplicatedOnce(ref, callback)
	if
		ref:IsDescendantOf(ReplicatedStorage)
		or ref:IsDescendantOf(workspace)
		or ref:IsDescendantOf(ReplicatedFirst)
	then
		callback()
		return
	end

	local con
	ref.AncestryChanged:Connect(function(_, parent)
		if parent == ReplicatedStorage or parent == workspace or parent == ReplicatedFirst then
			con = callback()
		elseif (parent == nil or parent.Parent == game) and con then
			con:Disconnect()
		end
	end)

	return function()
		if con then
			con:Disconnect()
		end
	end
end

function ReplicationUtils.getRemotes(man)
	local folder = ReplicatedStorage:WaitForChild(man.Name)
	local remotes = folder:WaitForChild("Remotes")

	return {
		ComponentAdded = remotes:WaitForChild("ComponentAdded");
		ComponentRemoved = remotes:WaitForChild("ComponentRemoved");
		StateChanged = remotes:WaitForChild("StateChanged");
	}
end

local function getOrMake(instance, name, class)
	local child = instance:FindFirstChild(name)
	if child then
		return child
	end

	child = Instance.new(class)
	child.Name = name
	child.Parent = instance
	
	return child
end

function ReplicationUtils.makeRemotes(man)
	local folder = getOrMake(ReplicatedStorage, man.Name, "Folder")
	local remotes = getOrMake(folder, "Remotes", "Folder")

	return {
		ComponentAdded = getOrMake(remotes, "ComponentAdded", "RemoteEvent");
		ComponentRemoved = getOrMake(remotes, "ComponentRemoved", "RemoteEvent");
		StateChanged = getOrMake(remotes, "StateChanged", "RemoteEvent");
	}
end

return ReplicationUtils