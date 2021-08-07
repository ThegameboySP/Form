local RunService = game:GetService("RunService")

local ComponentCollection = require(script.Parent.ComponentCollection)
local Reducers = require(script.Parent.Parent.Shared.Reducers)
local SignalMixin = require(script.Parent.SignalMixin)

local Manager = {
	DEBUG = true;
	isServer = RunService:IsServer();
}
Manager.__index = Manager

function Manager.new(name)
	assert(type(name) == "string", "Expected 'string'")

	local self = SignalMixin.new(setmetatable({
		Classes = {};
		Name = name;

		_hooks = {};
	}, Manager))
	
	self._collection = ComponentCollection.new(self)
	self._collection:On("ClassRegistered", function(class)
		self.Classes[class.BaseName] = class
		self:Fire("ClassRegistered", class)
	end)

	self:_forward(self._collection, "RefAdded")
	self:_forward(self._collection, "RefRemoving")
	self:_forward(self._collection, "RefRemoved")
	self:_forward(self._collection, "ComponentAdded")
	self:_forward(self._collection, "ComponentRemoved")

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


function Manager:GetTime()
	return tick()
end


function Manager:_forward(obj, eventName)
	return obj:On(eventName, function(...)
		self:Fire(eventName, ...)
	end)
end

return SignalMixin.wrap(Manager)