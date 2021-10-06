local Ops = require(script.Parent.Ops)
local Hooks = require(script.Parent.Parent.Parent.Composite.Hooks)

local Data = {}
Data.Ops = Ops
Data.__index = Data

local ALL = {}

function Data.new(extension, checkers, defaults)
	local buffer = {}

	return setmetatable({
		_extension = extension;
		_checkers = checkers;
		_defaults = defaults;
		
		buffer = setmetatable(buffer, buffer);
		layers = {};
		final = {};

		_subscriptions = Hooks.new();
	}, Data)
end

function Data:Destroy()
	self._subscriptions:Destroy()
	self.buffer = nil
	self.layers = nil
	self.top = nil
	self.bottom = nil
	self.final = nil
end

function Data:_subscribe(key, currentValue, handler)
	return self._subscriptions:On(key, function(newValue)
		if newValue == currentValue then return end

		local oldValue = currentValue
		currentValue = newValue
		handler(newValue, oldValue)
	end)
end

function Data:On(key, handler)
	return self:_subscribe(key, self.final[key], handler)
end

function Data:OnAll(handler)
	return self._subscriptions:On(ALL, handler)
end

function Data:For(key, handler)
	local currentValue = self.final[key]
	if currentValue ~= nil then
		handler(currentValue, nil)
	end

	return self:_subscribe(key, currentValue, handler)
end

function Data:ForAll(handler)
	if next(self.final) then
		handler(self.final, nil)
	end

	return self._subscriptions:On(ALL, handler)
end

function Data:onDelta(delta)
	local old = self.final
	local subscriptions = self._subscriptions

	local new = {}
	for k, v in pairs(old) do
		new[k] = v
	end

	for k, v in pairs(delta) do
		new[k] = v
	end

	self.final = new
	for k, v in pairs(delta) do
		subscriptions:Fire(k, v, old[k])
	end

	subscriptions:Fire(ALL, delta, new, old)
end

local function checkOrError(checker, k, v)
	if checker == nil then
		error(("No checker for key %q!"):format(k))
	end

	local ok, err = checker(v)
	if not ok then
		error(err)
	end
end

function Data:_setDirty(k)
	self.buffer[k] = nil
	self._extension:SetDirty(self, k)
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

function Data:CreateLayerAt(layerKey, keyToSet, layerToSet)
	if self.layers[keyToSet] then
		error(("Already inserted layer %q!"):format(keyToSet))
	end
	self:_checkOrError(layerToSet)
	local layer = self:_getLayerOrError(layerKey)

	for k in pairs(layerToSet) do
		self:_setDirty(k)
	end

	layerToSet.__index = layer
	layerToSet.prev = layer.prev
	self.layers[keyToSet] = setmetatable(layerToSet, layerToSet)

	layer.prev.__index = layerToSet
	layer.prev = layerToSet

	if layer == self.top then
		self.top = layerToSet
		self.buffer.__index = layerToSet
	end
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
		self:_set(layerKey, key, value)
	end
end

function Data:Get(key)
	local value = self.buffer[key]
	if type(value) == "function" then
		local final

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