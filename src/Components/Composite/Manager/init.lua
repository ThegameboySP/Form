local RunService = game:GetService("RunService")

local ComponentCollection = require(script.Parent.ComponentCollection)
local Reducers = require(script.Parent.Parent.Shared.Reducers)
local ComponentMode = require(script.Parent.Parent.Shared.ComponentMode)
local SignalMixin = require(script.Parent.SignalMixin)

local Manager = {
	DEBUG = true;
	isServer = RunService:IsServer();
}
Manager.__index = Manager

function Manager.new(name)
	assert(type(name) == "string")

	local self = SignalMixin.new(setmetatable({
		Classes = {};
		Name = name;

		_hooks = {};
		_profiles = {};
	}, Manager))
	
	self._collection = ComponentCollection.new(self)

	self._collection:On("RefAdded", function(ref)
		local profile = {ref = ref, componentsOrder = {}, mode = nil}
		self._profiles[ref] = profile
		self:Fire("RefAdded", ref, profile)
	end)

	self._collection:On("RefRemoving", function(ref)
		local profile = self._profiles[ref]
		local mode = profile.mode
		if mode == ComponentMode.Destroy then
			ref.Parent = nil
		end

		self:Fire("RefRemoving", ref, profile)
	end)

	self._collection:On("RefRemoved", function(ref)
		local profile = self._profiles[ref]
		self._profiles[ref] = nil
		self:Fire("RefRemoved", ref, profile)
	end)

	self._collection:On("ComponentAdded", function(ref, comp, keywords)
		local profile = self._profiles[ref]
		table.insert(profile.componentsOrder, comp)
		profile.mode = comp.mode

		self:Fire("ComponentAdded", ref, comp, keywords)
	end)

	self._collection:On("ComponentRemoved", function(ref, comp)
		local profile = self._profiles[ref]
		local order = profile.componentsOrder
		table.remove(order, table.find(order, comp))

		local lastComp = order[#order]
		if lastComp then
			profile.mode = lastComp.mode
		end

		self:Fire("ComponentRemoved", ref, comp)
	end)

	return self
end


function Manager:RegisterComponent(class)
	self._collection:Register(class)
end


function Manager:GetOrAddComponent(ref, classResolvable, keywords)
	return self._collection:GetOrAddComponent(ref, classResolvable, keywords)
end


function Manager:BulkAddComponent(refs, classes, configs)
	return self._collection:BulkAddComponent(refs, classes, configs)
end


function Manager:RemoveComponent(ref, classResolvable)
	return self._collection:RemoveComponent(ref, classResolvable)
end


function Manager:HasComponent(ref, classResolvable)
	return self._collection:HasComponent(ref, classResolvable)
end


function Manager:RemoveRef(ref)
	return self._collection:RemoveRef(ref)
end


function Manager:RegisterHook(name, hook)
	self._hooks[name] = self._hooks[name] or {}
	table.insert(self._hooks[name], hook)
end


function Manager:ReduceRunHooks(name, reducer, ...)
	local hooks = self._hooks[name]
	if hooks == nil then
		return nil
	end

	local values = {}
	for _, hook in ipairs(hooks) do
		table.insert(values, hook(...))
	end

	return reducer(values)
end


function Manager:RunHooks(name, ...)
	return self:ReduceRunHooks(name, Reducers.hook, ...)
end


function Manager:GetProfile(ref)
	return self._profiles[ref]
end


function Manager:DebugPrint(...)
	if self.DEBUG then
		warn("[Composite]", ...)
	end
end


function Manager:VerbosePrint(...)
	if self.DEBUG then
		warn("[Composite verbose]", ...)
	end
end


function Manager:Warn(...)
	warn("[Composite warning]", ...)
end

return SignalMixin.wrap(Manager)