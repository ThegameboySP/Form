local ComponentCollection = require(script.Parent.ComponentCollection)
local ComponentsUtils = require(script.Parent.Parent.Shared.ComponentsUtils)
local ComponentMode = require(script.Parent.Parent.Shared.ComponentMode)
local signalMixin = require(script.Parent.signalMixin)

local instanceConfigHook = require(script.instanceConfigHook)

local Manager = {
	DEBUG = true;
}
Manager.__index = Manager

Manager.new = signalMixin(Manager, function(name)
	assert(type(name) == "string")

	local self = setmetatable({
		Classes = {};
		Name = name;

		_hooks = {};
		_profiles = {};
	}, Manager)
	
	self:RegisterHook("GetConfig", instanceConfigHook)
	self._collection = ComponentCollection.new(self)

	self._collection:On("RefAdded", function(ref)
		self._profiles[ref] = {ref = ref, components = {}, mode = nil}
		self:Fire("RefAdded", ref)
	end)

	self._collection:On("RefRemoved", function(ref)
		local profile = self._profiles[ref]
		local mode = profile.mode
		if mode == ComponentMode.Destroy then
			ref.Parent = nil
		end

		self:Fire("RefRemoved", ref)
	end)

	self._collection:On("ComponentAdded", function(ref, comp)
		local profile = self._profiles[ref]
		profile.components[comp.BaseName] = true
		
		if comp.mode ~= ComponentMode.Default or profile.mode == nil then
			profile.mode = comp.mode
		end

		self:Fire("ComponentAdded", ref, comp)
	end)

	self._collection:On("ComponentRemoved", function(ref, comp)
		local profile = self._profiles[ref]
		profile.components[comp.BaseName] = nil

		self:Fire("ComponentRemoved", ref, comp)
	end)

	return self
end)


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


local HOOK_REDUCE = function(array)
	local type = type(array[1])

	if type == "table" then
		local final = {}
		for _, value in ipairs(array) do
			final = ComponentsUtils.shallowMerge(value, final)
		end

		return final
	elseif type == "nil" then
		return nil
	else
		return array[#array]
	end
end
function Manager:RunHooks(name, ...)
	return self:ReduceRunHooks(name, HOOK_REDUCE, ...)
end


function Manager:GetProfile(ref)
	return self._profiles[ref]
end


function Manager:DebugPrint(...)
	if self.DEBUG then
		warn("[Composite]", ...)
	end
end

return Manager