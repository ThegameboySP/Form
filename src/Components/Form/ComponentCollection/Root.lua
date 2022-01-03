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
local NO_KEY = Symbol.unique("noKey")

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

local function applyLayerToData(layer, Layers)
	local key
	if layer then
		key = layer.key or Layers:NewId()

		if Layers.layers[key] then
			Layers:SetLayer(key, layer.data)
		elseif layer.priority then
			Layers:CreateLayerAtPriority(key, layer.priority, layer.data)
		else
			Layers:CreateLayerBefore("base", key, layer.data)
		end
	end

	return key
end

function Root:PreStartComponent(class, layer)
	if class.CheckRef then
		assert(class.CheckRef(self.ref))
	end

	local comp = class.new(self.ref, self.man, self)
	comp.Layers = self.man.Embedded.Layers.new(comp)

	local key = applyLayerToData(layer, comp.Layers)

	self._callbacks.ComponentAdding(comp)
	self._hooks:Fire("ComponentAdding", comp)
	self.added[class] = comp

	return comp, self:_newId(comp, key)
end

function Root:GetOrAddComponentLoadless(resolvable, layer)
	local class = self.man._collection:ResolveOrError(resolvable)
	local comp = self.added[class]
	if comp == nil then
		local newComponent, id = self:PreStartComponent(class, layer)
		newComponent:OnAlways(RAN, function()
			self._callbacks.ComponentAdded(newComponent)
			self._hooks:Fire("ComponentAdded", newComponent)
		end)

		return newComponent, id
	end

	local key = applyLayerToData(layer, comp.Layers)

	return comp, self:_newId(comp, key)
end

function Root:GetOrAddComponent(resolvable, layer)
	local comp, id = self:GetOrAddComponentLoadless(resolvable, layer)
	comp:Run()
	return comp, id
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
		comp.Layers:RemoveLayer(key)
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