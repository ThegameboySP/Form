local ComponentCollection = require(script.Parent.ComponentCollection)
local ComponentsUtils = require(script.Parent.Parent.Shared.ComponentsUtils)

local instanceConfigHook = require(script.instanceConfigHook)

local Manager = {
	DEBUG = true
}
Manager.__index = Manager

function Manager.new(name)
	assert(type(name) == "string")

	local self = setmetatable({
		Classes = {};
		Name = name;

		_listeners = {};
		_anyListeners = {};
		_hooks = {};
	}, Manager)
	
	self:RegisterHook("GetConfig", instanceConfigHook)
	self._collection = ComponentCollection.new(self)

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


function Manager:On(name, handler)
	self._listeners[name] = self._listeners[name] or {}
	local listeners = self._listeners[name]
	table.insert(listeners, handler)

	return function()
		local i = table.find(listeners, handler)
		if i == nil then return end
		table.remove(listeners, i)
	end
end


function Manager:OnAny(handler)
	table.insert(self._anyListeners, handler)
	
	return function()
		local i = table.find(self._anyListeners, handler)
		if i == nil then return end
		table.remove(self._anyListeners, i)
	end
end


function Manager:Fire(name, ...)
	local tables = {self._anyListeners}
	table.insert(tables, 1, self._listeners[name])

	for _, listeners in ipairs(tables) do
		for _, handler in ipairs(listeners) do
			local co = coroutine.create(handler)
			local ok, err = coroutine.resume(co, ...)

			if not ok then
				warn(("Listener errored at %s\n%s"):format(debug.traceback(co), err))
			end
		end
	end
end


function Manager:DebugPrint(...)
	if self.DEBUG then
		warn("[Composite]", ...)
	end
end

return Manager