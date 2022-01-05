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

function ReplicationExtension.new(man, callbacks, overrides)
	local self = setmetatable({
		man = man;
		remotes = overrides or ReplicationUtils.makeRemotes(man);
		callbacks = {
			subscribePlayerAdded = callbacks and callbacks.subscribePlayerAdded;
			onReplicatedOnce = callbacks and callbacks.onReplicatedOnce or ReplicationUtils.onReplicatedOnce;
		};
		_replicatedComponents = setmetatable({}, {__mode = "k"});
	}, ReplicationExtension)

	self._onReplicated = function(comp)
		self._replicatedComponents[comp] = true

		self:_fireAll("ComponentAdded",
			self.man.Serializers:Serialize(comp), getCondensedData(comp.Layers, comp.Layers.set)
		)
	end

	return self
end

function ReplicationExtension:Init()
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

		self:_fire("InitPlayer", player, serializedRefs, resolvables, dataObjects)
	end

	if self.callbacks.subscribePlayerAdded then
		self.callbacks.subscribePlayerAdded(onPlayerAdded)
	else	
		Players.PlayerAdded:Connect(onPlayerAdded)
		for _, player in pairs(Players:GetPlayers()) do
			onPlayerAdded(player)
		end
	end

	self.man:On("ComponentAdded", function(comp)
		self:_onComponentAdded(comp)
	end)
	
	self.man:On("ComponentRemoved", function(comp)
		self:_onComponentRemoved(comp)
	end)
end

function ReplicationExtension:_onComponentAdded(comp)
	local destruct = self.callbacks.onReplicatedOnce(comp, self._onReplicated)

	if destruct then
		comp:OnAlways("Destroying", destruct)
	end

	comp.Layers:OnAll(function(delta)
		if self._replicatedComponents[comp] then
			self:_fireAll("StateChanged",
				self.man.Serializers:Serialize(comp), getCondensedData(comp.Layers, delta)
			)
		end
	end)
end

function ReplicationExtension:_onComponentRemoved(comp)
	self._replicatedComponents[comp] = nil
	self:_fireAll("ComponentRemoved", self.man.Serializers:Serialize(comp))
end

function ReplicationExtension:_fireAll(eventName, ...)
	self.remotes[eventName]:FireAllClients(...)
end

function ReplicationExtension:_fire(eventName, client, ...)
	self.remotes[eventName]:FireClient(client, ...)
end

return ReplicationExtension