local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ReplicationUtils = require(script.Parent.ReplicationUtils)

local ReplicationExtension = {}
ReplicationExtension.__index = ReplicationExtension

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

local function getRemotes(man)
	local folder = ReplicatedStorage:WaitForChild(man.Name)
	local remotes = folder:WaitForChild("Remotes")

	return {
		ComponentAdded = remotes:WaitForChild("ComponentAdded");
		ComponentRemoved = remotes:WaitForChild("ComponentRemoved");
		StateChanged = remotes:WaitForChild("StateChanged");
	}
end

local function makeRemotes(man)
	local folder = getOrMake(ReplicatedStorage, man.Name, "Folder")
	local remotes = getOrMake(folder, "Remotes", "Folder")

	return {
		ComponentAdded = getOrMake(remotes, "ComponentAdded", "RemoteEvent");
		ComponentRemoved = getOrMake(remotes, "ComponentRemoved", "RemoteEvent");
		StateChanged = getOrMake(remotes, "StateChanged", "RemoteEvent");
	}
end

function ReplicationExtension.new(man)
	return setmetatable({
		man = man;
		remotes = man.IsServer and makeRemotes(man) or getRemotes(man);
	}, ReplicationExtension)
end

function ReplicationExtension:InitServer()
	local function onPlayerAdded(player)
		for _, root in pairs(self.man._collection._rootByRef) do
			for class, comp in pairs(root.added) do
				self.remotes.ComponentAdded:FireClient(
					player, comp.ref, class.ClassName, comp.Data.final
				)
			end
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in pairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	self.man:On("ComponentRemoved", function(comp)
		self.remotes.ComponentRemoved:FireAllClients(comp.ref, comp.ClassName)
	end)

	self.man:On("ComponentAdded", function(comp)
		local didReplicate = false
		local destruct = ReplicationUtils.onReplicatedOnce(comp.ref, function()
			didReplicate = true
			self.remotes.ComponentAdded:FireAllClients(comp.ref, comp.ClassName, comp.Data.final)
		end)

		if destruct then
			comp:On("Destroying", destruct)
		end

		comp.Data:OnAll(function(delta)
			if didReplicate then
				self.remotes.StateChanged:FireAllClients(comp.ref, comp.ClassName, delta)
			end
		end)
	end)
end

function ReplicationExtension:InitClient()
	local layers = setmetatable({}, {__mode = "k"})

	task.defer(function()
		self.remotes.ComponentAdded.OnClientEvent:Connect(function(ref, className, data)
			if ref == nil then
				return self.man:Warn("Ref came back as nil. Component: " .. className)
			end

			local comp = self.man:GetComponent(ref, className)
			if comp and comp.__replicated then
				return self.man:Warn("Already added component " .. className)
			end

			local newComp, id = self.man:GetOrAddComponent(ref, className, {
				key = "remote";
				data = data;
			})

			layers[newComp] = id
			newComp.__replicated = true
		end)
	end)

	task.defer(function()
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
	end)

	task.defer(function()
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