local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkMode = require(script.Parent.Parent.Parent.NetworkMode)

local function networkModeFilter(class)
	return class.NetworkMode == NetworkMode.SERVER_CLIENT
		or class.NetworkMode == NetworkMode.SHARED
		or class.NetworkMode == NetworkMode.CLIENT
end

return function(man)
	local Replicator = {}
	man.Replicator = Replicator

	local folder = ReplicatedStorage:WaitForChild("CompositeReplication")
	local manFdr = folder:WaitForChild(man.Name)
	local addedRemote = manFdr:WaitForChild("ComponentAdded")
	local removedRemote = manFdr:WaitForChild("ComponentRemoved")

	addedRemote.OnClientEvent:Connect(function(ref, baseName, config)
		if ref == nil then
			return warn(("Cannot create component %s: reference does not exist on client!"):format(baseName))
		end

		local class =  man.Classes[baseName]
		if class == nil then
			return man:DebugPrint("Not adding", baseName, "because it's not registered")
		end

		if not networkModeFilter(class) then
			return man:DebugPrint("Not adding", baseName, "because it's a server only component")
		end

		man:DebugPrint("Adding", ref, baseName)
		man:GetOrAddComponent(ref, baseName, {config = config, source = "remote"})
	end)

	removedRemote.OnClientEvent:Connect(function(ref, baseName)
		if ref == nil then return end
		man:DebugPrint("Removing", ref, baseName)
		man:RemoveComponent(ref, baseName)
	end)
end