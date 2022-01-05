local ReplicationUtils = require(script.Parent.ReplicationUtils)

local ReplicationExtension = {}
ReplicationExtension.__index = ReplicationExtension

function ReplicationExtension.new(man, _, overrides)
	return setmetatable({
		man = man;
		remotes = overrides or ReplicationUtils.getRemotes(man);
		layers = setmetatable({}, {__mode = "k"});
	}, ReplicationExtension)
end

function ReplicationExtension:Init()
	-- Defer in case remotes are already queued. This should run first out of all Defer's this frame.
	local con
	con = self.man.Binding.Defer:ConnectAtPriority(0, function()
		con:Disconnect()
		
		self.remotes.InitPlayer.OnClientEvent:Connect(function(...)
			self:_onInitPlayer(...)
		end)

		self.remotes.ComponentAdded.OnClientEvent:Connect(function(...)
			self:_onComponentAdded(...)
		end)

		self.remotes.ComponentRemoved.OnClientEvent:Connect(function(...)
			self:_onComponentRemoved(...)
		end)

		self.remotes.StateChanged.OnClientEvent:Connect(function(...)
			self:_onStateChanged(...)
		end)
	end)
end

function ReplicationExtension:_onInitPlayer(serializedRefs, resolvables, dataObjects)
	local refs = {}
	local bulkLayers = {}

	for i, serializedRef in ipairs(serializedRefs) do
		local ref = self.man.Serializers:Deserialize(serializedRef)
		local comp = self.man:GetComponent(ref, resolvables[i])
		if comp and self.layers[comp] then
			self.man:Warn("Already added component " .. comp.ClassName)
			continue
		end
		
		refs[i] = ref
		self.layers[i] = {key = "remote", data = dataObjects[i]}
	end

	self.man:BulkAddComponent(refs, resolvables, bulkLayers)
end

function ReplicationExtension:_onComponentAdded(serializedComp, data)
	local comp = self.man.Serializers:Deserialize(serializedComp, "Error")

	if comp and self.layers[comp] then
		return self.man:Warn("Already added component " .. comp.ClassName)
	end

	local extracted = self.man.Serializers:Extract(serializedComp)
	local newComp, id = self.man:GetOrAddComponent(extracted.ref, extracted.name, {
		key = "remote";
		data = data;
	})

	self.layers[newComp] = id
end

function ReplicationExtension:_onComponentRemoved(serializedComp)
	local comp = self.man.Serializers:Deserialize(serializedComp, "Error")
	if comp == nil then return end

	local layer = self.layers[comp]
	self.layers[comp] = nil
	comp.root:RemoveLayer(comp, layer)
end

function ReplicationExtension:_onStateChanged(serializedComp, delta)
	local comp = self.man.Serializers:Deserialize(serializedComp, "Error")
	if comp == nil then return end
	
	comp.Layers:MergeLayer("remote", delta)
end

return ReplicationExtension