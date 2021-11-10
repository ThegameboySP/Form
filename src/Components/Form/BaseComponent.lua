local Hooks = require(script.Parent.Hooks)
local Symbol = require(script.Parent.Parent.Modules.Symbol)

local BaseComponent = {
	Ops = require(script.Parent.Parent.Extensions.Data).Ops;
	Utils = require(script.Parent.Parent.Shared.ComponentsUtils);
	t = require(script.Parent.Parent.Modules.t);
	ClassName = "BaseComponent";
	IsComponent = true;
}
BaseComponent.__index = BaseComponent

local RAN = Symbol.named("ran")

function BaseComponent.new(ref, man, root)
	return setmetatable({
		ref = ref;
		man = man;
		root = root;
		_hooks = Hooks.new();
		_rootIds = {};

		isDestroying = false;
		isInitialized = false;
		Data = nil;
	}, BaseComponent)
end

function BaseComponent:extend(name, class)
	class = class or {}

	for k, v in pairs(self) do
		if class[k] ~= nil then
			continue
		end
		
		class[k] = v
	end
	
	class.ClassName = name
	class.Inherits = self
	class.__index = class

	function class.new(...)
		return setmetatable(self.new(...), class)
	end

	return class
end

function BaseComponent:Destroy()
	if self.isDestroying then return end
	self.isDestroying = true

	self:Fire("Destroying")
	self:Fire("Destroyed")
	self._hooks:DisconnectAll()

	local root = self.root
	root.added[getmetatable(self)] = nil

	root._callbacks.ComponentRemoved(self)
	if not next(root.added) then
		root:Destroy()
	end
end

function BaseComponent:GetClass()
	return getmetatable(self)
end

function BaseComponent:CheckClassOrError(class)
	if self.CheckSubclass then
		local ok, err = self.CheckSubclass(class)
		if not ok then
			error(("Error class %q: %s"):format(self.ClassName, err), 2)
		end
	end

	return class
end

function BaseComponent:Run()
	if self.isInitialized then return end

	self:FireWithMethodName("Init", "OnInit")
	self:FireWithMethodName("Init", "OnStart")

	self:SetInitialized()

	return self
end

function BaseComponent:SetInitialized()
	if self.isInitialized then return end

	self.isInitialized = true
	self:Fire(RAN)
end

function BaseComponent:Fire(key, ...)
	if type(key) == "string" then
		local method = self["On" .. key]
		if type(method) == "function" then
			method(self, ...)
		end
	end

	self._hooks:Fire(key, ...)
end

function BaseComponent:FireWithMethodName(key, methodName, ...)
	local method = self[methodName]
	if method then
		method(self, ...)
	end

	self._hooks:Fire(key, ...)
end

function BaseComponent:On(key, handler)
	return self._hooks:On(key, handler)
end

function BaseComponent:OnAlways(key, handler)
	return self._hooks:OnAlways(key, handler)
end

function BaseComponent:Set(key, value)
	self.Data:Set("base", key, value)
end

function BaseComponent:Get(key)
	return self.Data:Get(key)
end

function BaseComponent:RawGet(key)
	return self.Data:RawGet(key)
end

function BaseComponent:__tostring()
	return string.format("Component (%s %s)", self.ref:GetFullName(), self.ClassName)
end

return BaseComponent