local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Symbol = require(script.Parent.Parent.Parent.Modules.Symbol)
local Utils = require(script.Parent.Utils)

return function(man)
	local Replicator = {}

	local folder = ReplicatedStorage:WaitForChild("CompositeReplication")
	local manFdr = folder:WaitForChild(man.Name)

	local added = manFdr:WaitForChild("ComponentAdded")
	local removed = manFdr:WaitForChild("ComponentRemoved")
	local stateChanged = manFdr:WaitForChild("StateChanged")
	local configChanged = manFdr:WaitForChild("ConfigChanged")
	local finalized = manFdr:WaitForChild("Finalized")

	added.OnClientEvent:Connect(function(ref, baseName, state, keywords)
		if ref == nil then
			return man:Warn("[Replication]", "Ref does not exist on client!")
		end

		local class =  man.Classes[baseName]
		if class == nil then
			return man:Warn("[Replication]", "Not adding", baseName, "because it's not registered")
		end

		if not Utils.shouldReplicate(class) then
			return man:Warn("[Replication]", "Not adding", baseName, "because it's a server only component")
		end

		man:DebugPrint("[Replication]", "Adding", Utils.path(ref, baseName))
		man:GetOrAddComponent(ref, baseName, {
			config = nil;
			mode = keywords.mode;
			isWeak = keywords.isWeak;
			layers = {
				[Symbol.named("remote")] = {state = state, config = keywords.config};
			};
		})
	end)

	removed.OnClientEvent:Connect(function(ref, baseName)
		if ref == nil then
			return man:Warn("[Replication]", "Ref does not exist on client!")
		end

		man:DebugPrint("[Replication]", "Removing", Utils.path(ref, baseName))
		man:RemoveComponent(ref, baseName)
	end)

	stateChanged.OnClientEvent:Connect(function(ref, baseName, delta)
		if ref == nil then
			return man:Warn("[Replication]", "Ref does not exist on client!")
		end

		man:VerbosePrint("[Replication]", "Changing state for", Utils.path(ref, baseName))
		local comp = man:GetComponent(ref, baseName)
		if comp == nil then
			return man:Warn("[Replication]", "No component for", Utils.path(ref, baseName) .. "!")
		end

		comp.Layers:Merge(Symbol.named("remote"), delta)
	end)

	configChanged.OnClientEvent:Connect(function(ref, baseName, config)
		if ref == nil then
			return warn("[Replication]", "Ref does not exist on client!")
		end

		man:VerbosePrint("[Replication]", "Changing config for", Utils.path(ref, baseName))
		local comp = man:GetComponent(ref, baseName)
		if comp == nil then
			return man:Warn("[Replication]", "No component for", Utils.path(ref, baseName) .. "!")
		end

		comp.Layers:SetConfig(Symbol.named("remote"), config)
	end)

	local isFinalized = Instance.new("BoolValue")
	isFinalized.Value = false
	finalized.OnClientEvent:Connect(function()
		isFinalized.Value = true
	end)
	Replicator.IsFinalized = isFinalized

	return Replicator
end