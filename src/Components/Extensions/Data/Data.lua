local Data = {}
Data.__index = Data

function Data.new(extension, base, checkers)
	return setmetatable({
		_extension = extension;
		_base = base;
		_onKeyChanged = base.OnKeyChanged;
		_checkers = checkers;
		
		buffer = setmetatable({}, {});
		layers = {};
		layersArray = {};
		top = nil;
	}, Data)
end

function Data:Destroy()
	self.buffer = nil
	self.layers = nil
	self.layersArray = nil
	self.top = nil
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

function Data:_insert(key, layerToSet)
	self:_checkOrError(layerToSet)

	local finalLayer = self.layers.final
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
		getmetatable(self.buffer).__index = layerToSet
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

function Data:_remove(layer)
	local mt = getmetatable(layer)
	local nextNode = mt.__index
	getmetatable(mt.prev).__index = nextNode

	if nextNode then
		getmetatable(nextNode).prev = mt.prev
	end

	table.remove(self.layersArray, table.find(self.layersArray, layer))
end

function Data:Remove(layerKey)
	local layer = self.layers[layerKey]
	if layer == nil then return end

	self:_remove(layer)

	for k, v in pairs(layer) do
		self.buffer[k] = nil
		if self._onKeyChanged then
			self._onKeyChanged(self._base, layerKey, k, v, nil)
		end
	end
end

function Data:_layerOverwritten(layerKey, existingLayer, layerToSet)
	existingLayer = existingLayer or {}

	for k, v in pairs(layerToSet) do
		self.buffer[k] = nil

		local oldValue = rawget(existingLayer, k)
		if oldValue ~= v then
			self._extension:SetDirty(self._base, k, oldValue)

			if self._onKeyChanged then
				self._onKeyChanged(self._base, k, k, v, oldValue)
			end
		end
	end

	for k, v in pairs(existingLayer) do
		if layerToSet[k] == nil then
			self.buffer[k] = nil
			self._extension:SetDirty(self._base, k, v)

			if self._onKeyChanged then
				self._onKeyChanged(self._base, layerKey, k, nil, v)
			end
		end
	end
end

function Data:SetLayer(layerKey, layerToSet)
	local existingLayer = self.layers[layerKey]

	if existingLayer then
		self:_checkOrError(layerToSet)

		self.layers[layerKey] = setmetatable(layerToSet, getmetatable(existingLayer))
		local index = table.find(self.layersArray, existingLayer)
		self.layersArray[index] = layerToSet

		self:_layerOverwritten(layerKey, existingLayer, layerToSet)
	else
		self:_insert(layerKey, layerToSet)
	end
end

function Data:CreateLayerAt(layerKey, keyToSet, layerToSet)
	self:_checkOrError(layerToSet)
	local layer = self:_getLayerOrError(layerKey)

	local existingLayer = self.layers[keyToSet]
	if existingLayer then
		self:_remove(existingLayer)
	end

	local layerMt = getmetatable(layer)
	setmetatable(layerToSet, {__index = layer, prev = layerMt.prev})
	getmetatable(layerMt.prev).__index = layerToSet
	layerMt.prev = layerToSet

	self.layers[keyToSet] = layerToSet

	local index = table.find(self.layersArray, layer)
	table.insert(self.layersArray, index + 1, layerToSet)

	self:_layerOverwritten(layerKey, existingLayer, layerToSet)
end

function Data:CreateLayerBefore(layerKey, keyToSet, layerToSet)
	self:_checkOrError(layerToSet)
	local layer = self:_getLayerOrError(layerKey)

	local existingLayer = self.layers[keyToSet]
	if existingLayer then
		self:_remove(keyToSet)
	end

	local layerMt = getmetatable(layer)
	setmetatable(layerToSet, {__index = layerMt.__index, prev = layer})
	if layerMt.__index then
		getmetatable(layerMt.__index).prev = layerToSet
	end
	
	self.layers[keyToSet] = layerToSet

	local index = table.find(self.layersArray, layer)
	table.insert(self.layersArray, index, layerToSet)

	self:_layerOverwritten(layerKey, existingLayer, layerToSet)
end

function Data:_set(layerKey, key, value)
	local layer = self.layers[layerKey]
	local oldValue = rawget(layer, key)
	layer[key] = value
	self.buffer[key] = nil

	self._extension:SetDirty(self._base, key, oldValue)

	if self._onKeyChanged then
		self._onKeyChanged(self._base, layerKey, key, value, oldValue)
	end
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

	local defaultLayer = self.layers.default
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