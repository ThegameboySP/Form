local RunService = game:GetService("RunService")

local ComponentCollection = require(script.Parent.ComponentCollection)
local Reducers = require(script.Parent.Parent.Shared.Reducers)
local SignalMixin = require(script.Parent.SignalMixin)
local Data = require(script.Parent.Parent.Extensions.Data)

local Manager = SignalMixin.wrap({
	DEBUG = true;
	IsTesting = false;
	IsServer = RunService:IsServer();
	IsRunning = RunService:IsRunning();
})
Manager.__index = Manager

function Manager.new(name)
	assert(type(name) == "string", "Expected 'string'")

	local self = SignalMixin.new(setmetatable({
		Data = nil;

		Classes = {};
		Embedded = {};
		Name = name;

		_hooks = {};
		_collection = nil;
	}, Manager))
	
	self._collection = ComponentCollection.new(self, {
		ComponentAdding = self:_forward("ComponentAdding");
		ComponentAdded = self:_forward("ComponentAdded");
		ComponentRemoved = self:_forward("ComponentRemoved");

		RefAdded = self:_forward("RefAdded");
		RefRemoving = self:_forward("RefRemoving");
		RefRemoved = self:_forward("RefRemoved");

		ClassRegistered = function(class)
			self.Classes[class.ClassName] = class
			self:Fire("ClassRegistered", class)
		end
	})

	self.Data = Data(self)

	return self
end


function Manager:RegisterComponent(class)
	if self.Classes[class.ClassName] then
		error(("Already registered class %q!"):format(class.ClassName), 2)
	end
	self._collection:Register(class)
end


function Manager:RegisterEmbedded(class)
	if self.Embedded[class.ClassName] then
		error(("Already registered embedded class %q!"):format(class.ClassName), 2)
	end
	self.Embedded[class.ClassName] = class
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


function Manager:Resolve(resolvable)
	return self._collection:Resolve(resolvable)
end


function Manager:ResolveOrError(resolvable)
	return self._collection:ResolveOrError(resolvable)
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


function Manager:_forward(eventName)
	return function(...)
		self:Fire(eventName, ...)
	end
end

return Manager