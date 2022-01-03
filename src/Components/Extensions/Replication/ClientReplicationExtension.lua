local ReplicationUtils = require(script.Parent.ReplicationUtils)

local ReplicationExtension = {}
ReplicationExtension.__index = ReplicationExtension

function ReplicationExtension.new(man, overrides)
	return setmetatable({
		man = man;
		remotes = overrides and overrides or ReplicationUtils.getRemotes(man);
	}, ReplicationExtension)
end

function ReplicationExtension:Init()
	local Serializers = self.man.Serializers
	local layers = setmetatable({}, {__mode = "k"})

	-- Defer in case remotes are already queued. This should run first out of all Defer's this frame.
	local con
	con = self.man.Binding.Defer:ConnectAtPriority(0, function()
		con:Disconnect()
		
		self.remotes.InitPlayer.OnClientEvent:Connect(function(serializedRefs, resolvables, dataObjects)
			local refs = {}
			local bulkLayers = {}

			for i, serializedRef in ipairs(serializedRefs) do
				local ref = Serializers:Deserialize(serializedRef)
				local comp = self.man:GetComponent(ref, resolvables[i])
				if comp and layers[comp] then
					self.man:Warn("Already added component " .. comp.ClassName)
					continue
				end
				
				refs[i] = ref
				layers[i] = {key = "remote", data = dataObjects[i]}
			end

			self.man:BulkAddComponent(refs, resolvables, bulkLayers)
		end)

		self.remotes.ComponentAdded.OnClientEvent:Connect(function(serializedComp, data)
			local comp = self.man.Serializers:Deserialize(serializedComp, "Error")

			if comp and layers[comp] then
				return self.man:Warn("Already added component " .. comp.ClassName)
			end

			local extracted = self.man.Serializers:Extract(serializedComp)
			local newComp, id = self.man:GetOrAddComponent(extracted.ref, extracted.name, {
				key = "remote";
				data = data;
			})

			layers[newComp] = id
		end)

		self.remotes.ComponentRemoved.OnClientEvent:Connect(function(serializedComp)
			local comp = self.man.Serializers:Deserialize(serializedComp, "Error")
			if comp == nil then return end

			local layer = layers[comp]
			layers[comp] = nil
			comp.root:RemoveLayer(comp, layer)
		end)

		self.remotes.StateChanged.OnClientEvent:Connect(function(serializedComp, delta)
			local comp = self.man.Serializers:Deserialize(serializedComp, "Error")
			if comp == nil then return end
			
			comp.Layers:MergeLayer("remote", delta)
		end)
	end)
end

return ReplicationExtension