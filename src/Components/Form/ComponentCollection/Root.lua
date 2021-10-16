local Hooks = require(script.Parent.Parent.Hooks)
local Symbol = require(script.Parent.Parent.Parent.Modules.Symbol)

local Root = {}
Root.__index = Root

--[[
	Bridges the gap between Manager and components.

	ALlows ComponentCollection to control it from the outside while
	allowing the interface to act like a component.
]]

local RAN = Symbol.named("ran")
local NO_KEY = Symbol.new("noKey")

function Root.new(man, ref, callbacks)
	return setmetatable({
		ref = ref;
		man = man;
		_callbacks = callbacks;
		_hooks = Hooks.new();
		added = {};
	}, Root)
end

function Root:Destroy()
	if rawget(self, "isDestroying") then return end
	self.isDestroying = true
	self._callbacks.Destroying()
	self._hooks:Fire("Destroying")

	for _, comp in pairs(self.added) do
		comp:Destroy()
	end

	self._callbacks.Destroyed()
	self._hooks:Fire("Destroyed")
end

function Root:_newId(comp, key)
	local id = #comp._rootIds + 1
	comp._rootIds[id] = key or NO_KEY
	return id
end

function Root:GetComponent(resolvable)
	return self.man:GetComponent(self.ref, resolvable)
end

function Root:PreStartComponent(class, layer)
	if class.CheckRef then
		assert(class.CheckRef(self.ref))
	end

	local comp = class.new(self.ref, self.man, self)

	self._callbacks.ComponentAdding(comp)
	self._hooks:Fire("ComponentAdding", comp)
	self.added[class] = comp

	local key
	if layer then
		key = layer.key or comp.Data:NewId()
		if comp.Data.layers[key] then
			comp.Data:SetLayer(key, layer.data)
		else
			comp.Data:CreateLayerBefore(
				"base", key, layer.data
			)
		end
	end

	return comp, self:_newId(comp, key)
end

function Root:GetOrAddComponent(resolvable, layer)
	local class = self.man._collection:ResolveOrError(resolvable)
	local comp = self.added[class]
	if comp == nil then
		local newComponent, id = self:PreStartComponent(class, layer)
		newComponent._hooks:OnAlways(RAN, function()
			self._callbacks.ComponentAdded(newComponent)
			self._hooks:Fire("ComponentAdded", newComponent)
		end)

		return newComponent, id
	end

	local key
	if layer then
		key = layer.key or comp.Data:NewId()
		if comp.Data.layers[key] then
			comp.Data:SetLayer(key, layer.data)
		else
			comp.Data:CreateLayerBefore(
				"base", key, layer.data
			)
		end
	end

	return comp, self:_newId(comp, key)
end

function Root:RemoveComponent(resolvable, ...)
	local class = self.man:ResolveOrError(resolvable)
	local comp = self.added[class]
	if comp == nil then return end

	comp:Destroy(...)
end

function Root:RemoveLayer(comp, id)
	local key = comp._rootIds[id]
	if key ~= NO_KEY then
		comp.Data:Remove(key)
	end

	comp._rootIds[id] = nil
	if next(comp._rootIds) == nil then
		comp:Destroy()
	end
end

-- function Root:QueueDestroyRef()
-- 	self:QueueDestroy():andThen(function()
-- 		self:DestroyRef()
-- 	end)
-- end

function Root:DestroyRef()
	self:Destroy()
	self.ref:Destroy()
end

function Root:On(eventName, handler)
	return self._hooks:On(eventName, handler)
end

function Root:Fire(eventName, ...)
	self._hooks:Fire(eventName, ...)
end

return Root