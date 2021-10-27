local Ops = require(script.Parent.Ops)
local Hooks = require(script.Parent.Parent.Parent.Form.Hooks)
local Symbol = require(script.Parent.Parent.Parent.Modules.Symbol)
local Constants = require(script.Parent.Parent.Parent.Form.Constants)

local Data = {}
Data.Ops = Ops
Data.__index = Data

local Object = {}
Object.__index = Object
Object.__mode = "v"

function Object.new(data, key)
	return setmetatable({
		_data = data or error("Data required");
		_key = key or error("Key required");
	}, Object)
end

function Object:Get()
	if self._data then
		return self._data:Get(self._key)
	end
	
	return nil
end

function Object:On(handler)
	return self._data:On(self._key, handler)
end

function Object:For(handler)
	return self._data:For(self._key, handler)
end

function Object:IsDestroyed()
	return not (self._data and self._data.buffer)
end

local NONE = Constants.None
local PRIORITY = Symbol.named("priority")
local ALL = {}

function Data.new(extension, checkers, defaults)
	local buffer = {}

	return setmetatable({
		_extension = extension;
		_checkers = checkers;
		_defaults = defaults;
		
		buffer = setmetatable(buffer, buffer);
		layers = {};
		set = {};
		_delta = {};
		_objects = {};

		_subscriptions = Hooks.new();
	}, Data)
end

function Data:Destroy()
	self._subscriptions:Destroy()
	self.buffer = nil
	self.layers = nil
	self.top = nil
	self.bottom = nil
	self.set = nil
	self._delta = nil
end

function Data:_subscribe(key, currentValue, handler)
	return self._subscriptions:On(key, function()
		local newValue = self:Get(key)
		if newValue == currentValue then return end

		local oldValue = currentValue
		currentValue = newValue
		handler(newValue, oldValue)
	end)
end

function Data:On(key, handler)
	return self:_subscribe(key, self:Get(key), handler)
end

function Data:OnAll(handler)
	return self._subscriptions:On(ALL, handler)
end

function Data:For(key, handler)
	local currentValue = self:Get(key)
	if currentValue ~= nil then
		handler(currentValue, nil)
		return self:_subscribe(key, currentValue, handler)
	end

	return self:_subscribe(key, currentValue, handler)
end

function Data:ForAll(handler)
	if next(self._delta) then
		handler(self._delta)
	end

	return self._subscriptions:On(ALL, handler)
end

function Data:onUpdate()
	if self.buffer == nil then return end
	local subscriptions = self._subscriptions
	local delta = self._delta

	for k in pairs(delta) do
		subscriptions:Fire(k)
	end

	subscriptions:Fire(ALL, delta)

	table.clear(delta)
end

local function checkOrError(checker, k, v)
	if checker == nil then
		error(("No checker for key %q!"):format(k))
	end

	if type(v) == "function" then
		return
	end
	
	local ok, err = checker(v)
	if not ok then
		error(err)
	end
end

function Data:_setDirty(k)
	self.buffer[k] = nil
	self._delta[k] = true
	self.set[k] = true
	self._extension[self] = true
end

function Data:_checkOrError(toCheck)
	if self._checkers then
		for k, v in pairs(toCheck) do
			checkOrError(self._checkers[k], k, v)
		end
	end
end

function Data:_getLayerOrError(layerKey)
	local layer = self.layers[layerKey]
	if layer == nil then
		error(("No layer by key %q!"):format(layerKey))
	end

	return layer
end

function Data:NewId()
	return #self.layers + 1
end

function Data:_rawInsert(key, layerToSet)
	local top = self.top
	if top then
		layerToSet.__index = top
		layerToSet.prev = self.buffer
		top.prev = layerToSet
	else
		layerToSet.prev = self.buffer
	end

	self.layers[key] = setmetatable(layerToSet, layerToSet)
	self.top = layerToSet
	self.buffer.__index = layerToSet

	if self.bottom == nil then
		self.bottom = layerToSet
	end

	return layerToSet
end

function Data:_insert(key, layerToSet)
	self:_checkOrError(layerToSet)

	for k in pairs(layerToSet) do
		self:_setDirty(k)
	end

	return self:_rawInsert(key, layerToSet)
end

function Data:InsertIfNil(key)
	local layer = self.layers[key]
	if layer == nil then
		return self:_insert(key, {})
	end

	return layer
end

function Data:_remove(layer)
	local nextNode = layer.__index
	layer.prev.__index = nextNode

	if nextNode then
		nextNode.prev = layer.prev
	end
end

function Data:Remove(layerKey)
	local layer = self.layers[layerKey]
	if layer == nil then return end

	self:_remove(layer)

	for k in pairs(layer) do
		if k == "__index" or k == "prev" then continue end
		self:_setDirty(k)
	end
end

function Data:SetLayer(layerKey, layerToSet)
	local existingLayer = self.layers[layerKey]

	if existingLayer then
		self:_checkOrError(layerToSet)

		for k in pairs(layerToSet) do
			self:_setDirty(k)
		end

		layerToSet.__index = existingLayer.__index
		layerToSet.prev = existingLayer.prev
		existingLayer.prev.__index = layerToSet
		self.layers[layerKey] = setmetatable(layerToSet, layerToSet)
	
		for k in pairs(existingLayer) do
			if k == "__index" or k == "prev" then continue end
			if layerToSet[k] == nil then
				self:_setDirty(k)
			end
		end
	else
		self:_insert(layerKey, layerToSet)
	end
end

function Data:_createLayerAt(at, keyToSet, layerToSet)
	layerToSet.__index = at
	layerToSet.prev = at.prev
	self.layers[keyToSet] = setmetatable(layerToSet, layerToSet)

	at.prev.__index = layerToSet
	at.prev = layerToSet

	if at == self.top then
		self.top = layerToSet
		self.buffer.__index = layerToSet
	end
end

function Data:CreateLayerAt(layerKey, keyToSet, layerToSet)
	if self.layers[keyToSet] then
		error(("Already inserted layer %q!"):format(keyToSet))
	end
	self:_checkOrError(layerToSet)
	local layer = self:_getLayerOrError(layerKey)

	for k in pairs(layerToSet) do
		self:_setDirty(k)
	end

	self:_createLayerAt(layer, keyToSet, layerToSet)
end

function Data:_createLayerBefore(layer, keyToSet, layerToSet)
	layerToSet.__index = layer.__index
	layerToSet.prev = layer
	self.layers[keyToSet] = setmetatable(layerToSet, layerToSet)

	if layer.__index then
		layer.__index.prev = layerToSet
	else
		self.bottom = layerToSet
	end

	layer.__index = layerToSet
end

function Data:CreateLayerBefore(layerKey, keyToSet, layerToSet)
	if self.layers[keyToSet] then
		error(("Already inserted layer %q!"):format(keyToSet))
	end
	self:_checkOrError(layerToSet)
	local layer = self:_getLayerOrError(layerKey)

	for k in pairs(layerToSet) do
		self:_setDirty(k)
	end

	self:_createLayerBefore(layer, keyToSet, layerToSet)
end

function Data:CreateLayerAtPriority(layerKey, priority, layerToSet)
	if self.layers[layerKey] then
		error(("Already inserted layer %q!"):format(layerKey))
	end
	self:_checkOrError(layerToSet)

	for k in pairs(layerToSet) do
		self:_setDirty(k)
	end
	layerToSet[PRIORITY] = priority

	local current = self.top
	local buffer = self.buffer
	local selected
	while current and current ~= buffer do
		local currentPriority = rawget(current, PRIORITY) or 0
		if priority >= currentPriority then
			selected = current
			break
		end
		current = current.__index
	end

	if selected then
		self:_createLayerAt(selected, layerKey, layerToSet)
	elseif self.bottom then
		self:_createLayerBefore(self.bottom, layerKey, layerToSet)
	else
		self:_rawInsert(layerKey, layerToSet)
	end
end

function Data:_set(layerKey, key, value)
	local layer = self.layers[layerKey]
	layer[key] = value
	self:_setDirty(key)
end

function Data:Set(layerKey, key, value)
	if self._checkers and value ~= nil then
		checkOrError(self._checkers[key], key, value)
	end

	self:_set(layerKey, key, value)
end

function Data:MergeLayer(layerKey, delta)
	self:_checkOrError(delta)
	
	for key, value in pairs(delta) do
		if value == NONE then
			self:_set(layerKey, key, nil)
		else
			self:_set(layerKey, key, value)
		end
	end
end

function Data:GetObject(key)
	local object = self._objects[key]
	if object then
		return object
	end

	object = Object.new(self, key)
	self._objects[key] = object

	return object
end

function Data:Get(key)
	local value = self.buffer[key]
	if type(value) == "function" then
		local final
		if self._defaults then
			final = self._defaults[key]
		end

		local current = self.bottom
		while current ~= self.buffer do
			local layerValue = rawget(current, key)
			current = current.prev

			if type(layerValue) == "function" then
				final = layerValue(final)
			elseif layerValue ~= nil then
				final = layerValue
			end
		end

		if final == nil and self._defaults then
			final = self._defaults[key]
		end
		
		self.buffer[key] = final

		return final
	end

	if value == nil and self._defaults then
		return self._defaults[key]
	end
	
	return value
end

return Data