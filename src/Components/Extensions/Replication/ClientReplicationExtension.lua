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
	local layers = setmetatable({}, {__mode = "k"})

	-- Defer in case remotes are already queued. This should run first out of all Defer's this frame.
	local con
	con = self.man.Binding.Defer:ConnectAtPriority(0, function()
		con:Disconnect()
		
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

			local layer = layers[comp]
			layers[comp] = nil
			comp.root:RemoveLayer(comp, layer)
		end)

		self.remotes.StateChanged.OnClientEvent:Connect(function(serializedComp, delta)
			local comp = self.man.Serializers:Deserialize(serializedComp, "Error")
			
			comp.Data:MergeLayer("remote", delta)
		end)
	end)
end

return ReplicationExtension