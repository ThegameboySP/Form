local ReplicationUtils = require(script.Parent.ReplicationUtils)

local ReplicationExtension = {}
ReplicationExtension.__index = ReplicationExtension

function ReplicationExtension.new(man)
	return setmetatable({
		man = man;
		remotes = ReplicationUtils.getRemotes(man);
	}, ReplicationExtension)
end

function ReplicationExtension:Init()
	local layers = setmetatable({}, {__mode = "k"})

	-- Defer in case remotes are already queued. This should run first out of all Defer's this frame.
	self.man.Binding.Defer:ConnectAtPriority(0, function()
		self.remotes.ComponentAdded.OnClientEvent:Connect(function(ref, className, data)
			if ref == nil then
				return self.man:Warn("Ref came back as nil. Component: " .. className)
			end

			local comp = self.man:GetComponent(ref, className)
			if comp and layers[comp] then
				return self.man:Warn("Already added component " .. className)
			end

			local newComp, id = self.man:GetOrAddComponent(ref, className, {
				key = "remote";
				data = data;
			})

			layers[newComp] = id
		end)

		self.remotes.ComponentRemoved.OnClientEvent:Connect(function(ref, className)
			if ref == nil then
				return self.man:Warn("Ref came back as nil. Component: " .. className)
			end

			local comp = self.man:GetComponent(ref, className)
			if comp then
				local layer = layers[comp]
				layers[comp] = nil
				comp.root:RemoveLayer(comp, layer)
			end
		end)

		self.remotes.StateChanged.OnClientEvent:Connect(function(ref, className, delta)
			if ref == nil then
				return self.man:Warn("Ref came back as nil. Component: " .. className)
			end

			local comp = self.man:GetComponent(ref, className)
			if comp == nil then
				return self.man:Warn(("StateChanged: No component for ref %s with class %s!"):format(ref:GetFullName(), className))
			end

			comp.Data:MergeLayer("remote", delta)
		end)
	end)
end

return ReplicationExtension