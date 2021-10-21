local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")

local getOrMake = require(script.Parent.Parent.Parent.Form.getOrMake)

local ReplicationUtils = {}

function ReplicationUtils.onReplicatedOnce(ref, callback)
	if
		ref:IsDescendantOf(ReplicatedStorage)
		or ref:IsDescendantOf(workspace)
		or ref:IsDescendantOf(ReplicatedFirst)
		or ref:IsDescendantOf(Players)
	then
		callback()
		return
	end

	local con
	ref.AncestryChanged:Connect(function(_, parent)
		if parent == ReplicatedStorage or parent == workspace or parent == ReplicatedFirst or parent == Players then
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

function ReplicationUtils.makeRemotes(man)
	local remotes = getOrMake(man.Folder, "Remotes", "Folder")

	return {
		ComponentAdded = getOrMake(remotes, "ComponentAdded", "RemoteEvent");
		ComponentRemoved = getOrMake(remotes, "ComponentRemoved", "RemoteEvent");
		StateChanged = getOrMake(remotes, "StateChanged", "RemoteEvent");
	}
end

return ReplicationUtils