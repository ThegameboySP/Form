local RunService = game:GetService("RunService")

local ComponentCollection = require(script.Parent.ComponentCollection)
local Hooks = require(script.Parent.Hooks)
local Data = require(script.Parent.Parent.Extensions.Data)

local Manager = {
	DEBUG = true;
	IsTesting = false;
	IsServer = RunService:IsServer();
	IsRunning = RunService:IsRunning();
}
Manager.__index = Manager

local function forward(hooks, hookName)
	return function(...)
		hooks:Fire(hookName, ...)
	end
end

function Manager.new(name)
	assert(type(name) == "string", "Expected 'string'")

	local self = setmetatable({
		Data = nil;
		
		Classes = {};
		Embedded = {};
		Name = name;
		
		_hooks = Hooks.new();
		_collection = nil;
	}, Manager)
	
	local hooks = self._hooks
	self._collection = ComponentCollection.new(self, {
		ComponentAdding = function(comp)
			for _, embedded in pairs(self.Embedded) do
				comp[embedded.Name or embedded.ClassName] = embedded.new(comp)
			end
			hooks:Fire("ComponentAdding", comp)
		end;
		ComponentAdded = forward(hooks, "ComponentAdded");
		ComponentRemoved = forward(hooks, "ComponentRemoved");

		RefAdded = forward(hooks, "RefAdded");
		RefRemoving = forward(hooks, "RefRemoving");
		RefRemoved = forward(hooks, "RefRemoved");

		Destroying = forward(hooks, "RefRemoving");
		Destroyed = forward(hooks, "RefRemoved");

		ClassRegistered = function(class)
			self.Classes[class.ClassName] = class
			hooks:Fire("ClassRegistered", class)
		end
	})

	self.Data = Data.use(self)

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


function Manager:GetComponent(ref, classResolvable)
	return self._collection:GetComponent(ref, classResolvable)
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


function Manager:On(key, handler)
	return self._hooks:On(key, handler)
end


function Manager:Fire(key, ...)
	return self._hooks:Fire(key, ...)
end


function Manager:Resolve(resolvable)
	return self._collection:Resolve(resolvable)
end


function Manager:ResolveOrError(resolvable)
	return self._collection:ResolveOrError(resolvable)
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

return Manager