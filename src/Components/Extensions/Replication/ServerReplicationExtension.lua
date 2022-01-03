local Players = game:GetService("Players")

local ReplicationUtils = require(script.Parent.ReplicationUtils)
local Constants = require(script.Parent.Parent.Parent.Form.Constants)

local ReplicationExtension = {}
ReplicationExtension.__index = ReplicationExtension

local NONE = Constants.None

local function getCondensedData(Layers, delta)
	local condensed = {}

	for key in pairs(delta) do
		local value = Layers.buffer[key]
		if value == nil then
			condensed[key] = NONE
		else
			condensed[key] = value
		end
	end

	return condensed
end

local COMPONENT_ADDED = function(self, comp)
	local didReplicate = false

	local destruct = ReplicationUtils.onReplicatedOnce(comp.ref, function()
		didReplicate = true
		self._replicatedComponents[comp] = true

		self.remotes.ComponentAdded:FireAllClients(
			self.man.Serializers:Serialize(comp), getCondensedData(comp.Layers, comp.Layers.set)
		)
	end)

	if destruct then
		comp:OnAlways("Destroying", destruct)
	end

	comp.Layers:OnAll(function(delta)
		if didReplicate then
			self.remotes.StateChanged:FireAllClients(
				self.man.Serializers:Serialize(comp), getCondensedData(comp.Layers, delta)
			)
		end
	end)
end;

local COMPONENT_REMOVED = function(self, comp)
	self._replicatedComponents[comp] = nil
	self.remotes.ComponentRemoved:FireAllClients(self.man.Serializers:Serialize(comp))
end

local FIRE_CLIENT = function(self, client, serializedRefs, resolvables, dataObjects)
	self.remotes.InitPlayer:FireClient(client, serializedRefs, resolvables, dataObjects)
end

function ReplicationExtension.new(man, overrides)
	return setmetatable({
		man = man;
		remotes = overrides and overrides or ReplicationUtils.makeRemotes(man);
		_replicatedComponents = setmetatable({}, {__mode = "k"});
	}, ReplicationExtension)
end

function ReplicationExtension:Init(callbacks)
	callbacks = callbacks or {}

	local fireClient = callbacks.FireInitialClient or FIRE_CLIENT

	local function onPlayerAdded(player)
		local Serializers = self.man.Serializers

		local serializedRefs = {}
		local resolvables = {}
		local dataObjects = {}

		local i = 1
		for comp in pairs(self._replicatedComponents) do
			serializedRefs[i] = Serializers:Serialize(comp.ref)
			resolvables[i] = comp.ClassName
			dataObjects[i] = getCondensedData(comp.Layers, comp.Layers.set)
			i += 1
		end

		fireClient(self, player, serializedRefs, resolvables, dataObjects)
	end

	if callbacks.SubscribePlayerAdded then
		callbacks.SubscribePlayerAdded(onPlayerAdded)
	else	
		Players.PlayerAdded:Connect(onPlayerAdded)
		for _, player in pairs(Players:GetPlayers()) do
			onPlayerAdded(player)
		end
	end

	local added = callbacks.ComponentAdded or COMPONENT_ADDED
	local removed = callbacks.ComponentRemoved or COMPONENT_REMOVED
	self.man:On("ComponentAdded", function(comp)
		added(self, comp, COMPONENT_ADDED)
	end)
	
	self.man:On("ComponentRemoved", function(comp)
		removed(self, comp, COMPONENT_REMOVED)
	end)
end

return ReplicationExtension