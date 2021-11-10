local Players = game:GetService("Players")

local ReplicationUtils = require(script.Parent.ReplicationUtils)
local Constants = require(script.Parent.Parent.Parent.Form.Constants)

local ReplicationExtension = {}
ReplicationExtension.__index = ReplicationExtension

local NONE = Constants.None

local function getCondensedData(Data, delta)
	local condensed = {}

	for key in pairs(delta) do
		local value = Data:Get(key)
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
			self.man.Serializers:Serialize(comp), getCondensedData(comp.Data, comp.Data.set)
		)
	end)

	if destruct then
		comp:OnAlways("Destroying", destruct)
	end

	comp.Data:OnAll(function(delta)
		if didReplicate then
			self.remotes.StateChanged:FireAllClients(
				self.man.Serializers:Serialize(comp), getCondensedData(comp.Data, delta)
			)
		end
	end)
end;

local COMPONENT_REMOVED = function(self, comp)
	self._replicatedComponents[comp] = nil
	self.remotes.ComponentRemoved:FireAllClients(self.man.Serializers:Serialize(comp))
end

local FIRE_CLIENT = function(self, client, comp, data)
	self.remotes.ComponentAdded:FireClient(
		client, self.man.Serializers:Serialize(comp), data
	)
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
		for comp in pairs(self._replicatedComponents) do
			fireClient(self, player, comp, getCondensedData(comp.Data, comp.Data.set))
		end
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