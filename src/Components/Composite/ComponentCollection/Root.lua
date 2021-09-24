local t = require(script.Parent.Parent.Parent.Modules.t)

local Root = {}
Root.__index = Root

local NO_DATA = {}

--[[
	Bridges the gap between Manager and components.

	ALlows ComponentCollection to control it from the outside while
	allowing the interface to act like a component.
]]


function Root.new(man, ref, callbacks)
	return setmetatable({
		ref = ref;
		man = man;
		_callbacks = callbacks;

		added = {};
		isDestroying = false;
		ids = {};
	}, Root)
end

function Root:Destroy()
	if self.isDestroying then return end
	self.isDestroying = true
	self._callbacks.Destroying()

	for _, comp in pairs(self.added) do
		comp:Destroy()
	end
	self.added = nil
	self.ids = nil

	self._callbacks.Destroyed()
end

function Root:GetComponent(resolvable)
	return self.man:GetComponent(self.ref, resolvable)
end

function Root:_newLayer(comp, key)
	local entry = self.ids[comp]
	if entry == nil then
		entry = {}
		self.ids[comp] = entry
	end

	local new = #entry + 1
	entry[new] = key or NO_DATA

	return new
end

function Root:PreStartComponent(class, keywords)
	if self.added[class] then
		error(("Already added class %q on reference %q!"):format(
			class.ClassName, self.ref:GetFullName()
		))
	end

	if class.checkRef then
		assert(class.checkRef(self.ref))
	end

	local comp = class.new(self.ref)

	local embeddeds = {}
	for _, embedded in pairs(self.man.Embedded) do
		if embedded.shouldApply and not embedded.shouldApply(comp) then continue end

		comp[embedded.ClassName] = embedded.new(comp)
		if embedded.Init then
			table.insert(embeddeds, embedded)
		end
	end

	for _, embedded in pairs(embeddeds) do
		embedded:Init()
	end

	local layer = keywords.layer
	if layer then
		comp.Data:CreateLayerBefore(
			"base", layer.key or comp.Data:NewId(), layer.data
		)
	end

	self._callbacks.ComponentAdding(comp)
	self.added[class] = comp
	if keywords.onAdding then
		keywords.onAdding(comp)
	end
	
	comp:On("Destroying", function()
		self.added[class] = nil
		self.ids[comp] = nil

		self._callbacks.ComponentRemoved(comp)
		if not next(self.added) then
			self:Destroy()
		end
	end)

	return comp, self:_newLayer(comp, layer and layer.key)
end

local IKeywords = t.strictInterface({
	layer = t.optional(t.strictInterface({
		key = t.optional(t.string);
		data = t.table;
	}));

	onAdding = t.optional(t.callback);
})
function Root:GetOrAddComponent(resolvable, keywords)
	keywords = keywords or {}
	assert(IKeywords(keywords))
	
	local class = self.man:ResolveOrError(resolvable)
	if self.added[class] == nil then
		local comp, id = self:PreStartComponent(class, keywords)
		comp:Start()
		self._callbacks.ComponentAdded(comp)

		return comp, id
	end

	local comp = self.added[class]
	local key
	if keywords.layer then
		key = keywords.layer.key or comp.Data:NewId()
		comp.Data:CreateLayerBefore(
			"base", key, keywords.layer.data
		)
	end

	return comp, self:_newLayer(comp, key or comp.Data:NewId())
end

function Root:RemoveLayer(resolvable, layerKey)
	local class = self.man:ResolveOrError(resolvable)
	local comp = self.added[class]
	if comp == nil then return end

	local entry = self.ids[comp]
	comp.Data:RemoveLayer(entry[layerKey])
	entry[layerKey] = nil

	if not next(entry) then
		self:RemoveComponent(class)
	end
end

function Root:RemoveComponent(resolvable, ...)
	local class = self.man:ResolveOrError(resolvable)
	local comp = self.added[class]
	if comp == nil then return end

	comp:Destroy(...)
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

return Root