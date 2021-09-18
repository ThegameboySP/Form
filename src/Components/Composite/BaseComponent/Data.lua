local Symbol = require(script.Parent.Parent.Parent.Modules.Symbol)

local Data = {}
Data.__index = Data

local FINAL = Symbol.named("final")
local DEFAULT = Symbol.named("default")
Data.Final = FINAL
Data.Default = DEFAULT

function Data.new(extension, base, checkers)
	local bufferMt = {}

	return setmetatable({
		_extension = extension;
		_base = base;
		_onKeyChanged = base.OnKeyChanged;
		_checkers = checkers;
		
		buffer = setmetatable({}, bufferMt);
		_bufferMt = bufferMt;
		layers = {};
		layersArray = {};
		top = nil;
	}, Data)
end

local function checkValue(checker, key, value)
	if checker == nil then
		error(("No checker for key %q!"):format(key))
	end

	local ok, err = checker(value)
	if not ok then
		error(err)
	end
end

function Data:NewId()
	return #self.layers + 1
end

function Data:_insert(key, layerToSet)
	if self._checkers then
		for k, v in pairs(layerToSet) do
			checkValue(self._checkers[k], k, v)
		end
	end

	local finalLayer = self.layers[FINAL]
	if finalLayer then
		local topMt = getmetatable(self.top)
		local last = topMt.__index
		setmetatable(layerToSet, {__index = last, prev = finalLayer})

		local lastMt = getmetatable(last)
		if lastMt then
			lastMt.prev = layerToSet
		end

		topMt.__index = layerToSet
		self.layers[key] = layerToSet

		local index = table.find(self.layersArray, finalLayer)
		table.insert(self.layersArray, index + 1, layerToSet)
	else
		local top = self.top
		if top then
			setmetatable(layerToSet, {__index = top, prev = self.buffer})
			getmetatable(top).prev = layerToSet
		else
			setmetatable(layerToSet, {prev = self.buffer})
		end

		self.layers[key] = layerToSet
		self.top = layerToSet
		self._bufferMt.__index = layerToSet
		table.insert(self.layersArray, layerToSet)
	end

	for k, v in pairs(layerToSet) do
		self.buffer[k] = nil
		if self._onKeyChanged then
			self._onKeyChanged(self._base, key, k, v, nil)
		end
	end

	return layerToSet
end

function Data:InsertIfNil(key)
	local layer = self.layers[key]
	if layer == nil then
		return self:_insert(key, {})
	end

	return layer
end

function Data:Remove(layerKey)
	local layer = self.layers[layerKey]
	if layer == nil then return end

	local mt = getmetatable(layer)
	local nextNode = mt.__index
	getmetatable(mt.prev).__index = nextNode

	if nextNode then
		getmetatable(nextNode).prev = mt.prev
	end

	table.remove(self.layersArray, table.find(self.layersArray, layer))

	for k, v in pairs(layer) do
		self.buffer[k] = nil
		if self._onKeyChanged then
			self._onKeyChanged(self._base, layerKey, k, v, nil)
		end
	end
end

function Data:SetLayer(layerKey, layerToSet)
	local buffer = self.buffer
	local existingLayer = self.layers[layerKey]

	if existingLayer then
		if self._checkers then
			for k, v in pairs(layerToSet) do
				checkValue(self._checkers[k], k, v)
			end
		end

		self.layers[layerKey] = setmetatable(layerToSet, getmetatable(existingLayer))
		local index = table.find(self.layersArray, existingLayer)
		self.layersArray[index] = layerToSet

		for k in pairs(existingLayer) do
			buffer[k] = nil
		end

		for k, v in pairs(layerToSet) do
			self.buffer[k] = nil
			if self._onKeyChanged then
				self._onKeyChanged(self._base, layerKey, k, v, nil)
			end
		end
	else
		self:_insert(layerKey, layerToSet)
	end
end

function Data:CreateLayerAt(key, keyToSet, layerToSet)
	local layer = self.layers[key]
	if layer == nil then
		return self:_insert(key, layerToSet)
	end

	if self._checkers then
		for k, v in pairs(layerToSet) do
			checkValue(self._checkers[k], k, v)
		end
	end

	local existingLayer = self.layers[keyToSet]
	if existingLayer then
		self:Remove(keyToSet)
	end

	local layerMt = getmetatable(layer)
	local prevMt = getmetatable(layerMt.prev)

	setmetatable(layerToSet, {__index = layer, prev = prevMt.prev})
	prevMt.__index = layerToSet
	layerMt.prev = layerToSet

	self.layers[keyToSet] = layerToSet
	
	local index = table.find(self.layersArray, layer)
	table.insert(self.layersArray, index + 1, layerToSet)

	existingLayer = existingLayer or {}
	for k, v in pairs(layerToSet) do
		self.buffer[k] = nil

		local oldValue = rawget(existingLayer, k)
		if self._onKeyChanged and oldValue ~= v then
			self._onKeyChanged(self._base, key, k, v, oldValue)
		end
	end

	for k, v in pairs(existingLayer) do
		if layerToSet[k] == nil then
			self.buffer[k] = nil

			if self._onKeyChanged then
				self._onKeyChanged(self._base, key, k, nil, v)
			end
		end
	end

	return keyToSet
end

function Data:_set(layerKey, key, value)
	local layer = self.layers[layerKey]
	local oldValue = rawget(layer, key)
	layer[key] = value
	self.buffer[key] = nil

	self._extension:SetDirty(self._base, key)

	if self._onKeyChanged then
		self._onKeyChanged(self._base, layerKey, key, value, oldValue)
	end
end

function Data:Set(layerKey, key, value)
	if self._checkers and value ~= nil then
		checkValue(self._checkers[key], key, value)
	end

	self:_set(layerKey, key, value)
end

function Data:MergeLayer(layerKey, delta)
	if self._checkers then
		for key, value in pairs(delta) do
			checkValue(self._checkers[key], key, value)
		end
	end

	for key, value in pairs(delta) do
		self:_set(layerKey, key, value)
	end
end

function Data:Get(key)
	local value = self.buffer[key]
	if type(value) == "function" then
		local final

		for _, layer in ipairs(self.layersArray) do
			local layerValue = rawget(layer, key)
			
			if type(layerValue) == "function" then
				final = layerValue(final)
			elseif layerValue ~= nil then
				final = layerValue
			end
		end
		
		self.buffer[key] = final
		return final
	end
	
	return value
end

function Data:GetValues(key)
	local values = {}
	local i = 0

	local defaultLayer = self.layers[DEFAULT]
	for _, layer in ipairs(self.layersArray) do
		if layer == defaultLayer then continue end
		
		local value = rawget(layer, key)

		if type(value) == "function" then
			if i > 0 then
				values[i] = value(values[i])
			else
				i = 1
				values[1] = value(nil)
			end
		elseif value ~= nil then
			i += 1
			values[i] = value
		end
	end

	return values
end

return Data