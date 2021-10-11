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
		self.remotes.ComponentAdded:FireAllClients(
			comp.ref, comp.ClassName, getCondensedData(comp.Data, comp.Data.set)
		)
	end)

	if destruct then
		comp:On("Destroying", destruct)
	end

	comp.Data:OnAll(function(delta)
		if didReplicate then
			self.remotes.StateChanged:FireAllClients(
				comp.ref, comp.ClassName, getCondensedData(comp.Data, delta)
			)
		end
	end)
end;

local COMPONENT_REMOVED = function(self, comp)
	if comp.root.isDestroying then
		return
	end

	self.remotes.ComponentRemoved:FireAllClients(comp.ref, comp.ClassName)
end

function ReplicationExtension.new(man)
	return setmetatable({
		man = man;
		remotes = ReplicationUtils.makeRemotes(man);
	}, ReplicationExtension)
end

function ReplicationExtension:Init(callbacks)
	callbacks = callbacks or {}

	local function onPlayerAdded(player)
		for _, root in pairs(self.man._collection._rootByRef) do
			for class, comp in pairs(root.added) do
				self.remotes.ComponentAdded:FireClient(
					player, comp.ref, class.ClassName, getCondensedData(comp.Data, comp.Data.set)
				)
			end
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in pairs(Players:GetPlayers()) do
		onPlayerAdded(player)
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