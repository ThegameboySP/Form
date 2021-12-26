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
		return self._data.buffer[self._key]
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
local ALL = Symbol.unique("all")

local bufferOrder = {}

local bufferMt = {
	__index = function(self, key)
		local resolved = if self.__index == false then nil else self.__index[key]

		if type(resolved) == "table" and resolved.__transform then
			local toBottom = self.__index
			local orderIndex = 0
			resolved = nil

			while toBottom do
				local layerValue = rawget(toBottom, key)

				if layerValue == nil or (type(layerValue) == "table" and layerValue.__transform) then
					toBottom = toBottom.__index
					orderIndex += 1
					bufferOrder[orderIndex] = layerValue

					continue
				end

				resolved = layerValue
				break
			end

			if resolved == nil and self.__defaults then
				resolved = self.__defaults[key]
			end

			-- Copy the table so transforms can safely mutate it.
			if type(resolved) == "table" then
				local copy = {}
				for k, v in pairs(resolved) do
					copy[k] = v
				end
				resolved = copy
			end

			for i=orderIndex, 1, -1 do
				local layerValue = bufferOrder[i]
				
				if layerValue ~= nil then
					local nextResolved = layerValue.__transform(resolved)

					-- If transform's parameter was nil, it returned its injected table.
					-- Copy it so other transforms can safely mutate it.
					if resolved == nil and type(nextResolved) == "table" then
						resolved = {}
						for k, v in pairs(nextResolved) do
							resolved[k] = v
						end
					else
						resolved = nextResolved
					end
				end
			end

			table.clear(bufferOrder)
		end

		if resolved == nil and self.__defaults then
			resolved = self.__defaults[key]
		end
		
		self[key] = resolved

		return resolved
	end
}

local function getPrevious(top, layer)
	local current = top

	while true do
		local nextLayer = current.__index
		if nextLayer and nextLayer ~= layer then
			current = nextLayer
		else
			return current
		end
	end

	return nil
end

function Data.new(extension, checkers, defaults)
	return setmetatable({
		_extension = extension;
		_checkers = checkers;
		
		buffer = setmetatable({
			__index = false;
			__defaults = defaults or false;
		}, bufferMt);
		layers = {};
		set = {};
		_delta = {};
		_objects = {};

		_subscriptions = Hooks.new();
	}, Data)
end

function Data:Destroy()
	self._subscriptions:Destroy()
	self.buffer.__index = nil
	self.buffer = nil
	self.layers = nil
	self.set = nil
	self._delta = nil
	self._objects = nil
end

function Data:On(key, handler)
	return self._subscriptions:On(key, handler)
end

function Data:OnAll(handler)
	return self._subscriptions:On(ALL, handler)
end

function Data:For(key, handler)
	local currentValue = self.buffer[key]
	if currentValue ~= nil then
		local oldValue = self._delta[key]
		handler(currentValue, if oldValue == NONE then nil else oldValue)
	end

	return self._subscriptions:On(key, handler)
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
	local buffer = self.buffer

	for k, oldValue in pairs(delta) do
		subscriptions:Fire(k, buffer[k], if oldValue == NONE then nil else oldValue)
	end

	subscriptions:Fire(ALL, delta)

	table.clear(delta)
end

local function checkOrError(checker, k, v)
	if checker == nil then
		error(("No checker for key %s"):format(k))
	end

	if type(v) == "table" and v.__transform then
		v = v.__transform(nil)
	end
	
	local ok, err = checker(v)
	if not ok then
		error(("Could not set %s: %s"):format(k, err))
	end
end

function Data:_setDirty(k)
	if self._delta[k] == nil then
		local value = self.buffer[k]
		self._delta[k] = if value == nil then NONE else value
	end

	self.buffer[k] = nil
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
	local top = self.buffer.__index
	if top then
		layerToSet.__index = top
	end

	self.layers[key] = setmetatable(layerToSet, layerToSet)
	self.buffer.__index = layerToSet

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

function Data:RemoveLayer(layerKey)
	local layer = self.layers[layerKey]
	if layer == nil then return end

	getPrevious(self.buffer, layer).__index = layer.__index

	for k in pairs(layer) do
		if k == "__index" then continue end
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
		getPrevious(self.buffer, existingLayer).__index = layerToSet
		self.layers[layerKey] = setmetatable(layerToSet, layerToSet)
	
		for k in pairs(existingLayer) do
			if k == "__index" then continue end
			self:_setDirty(k)
		end
	else
		self:_insert(layerKey, layerToSet)
	end
end

function Data:_createLayerAfter(at, keyToSet, layerToSet)
	layerToSet.__index = at
	self.layers[keyToSet] = setmetatable(layerToSet, layerToSet)
	getPrevious(self.buffer, at).__index = layerToSet
end

function Data:CreateLayerAfter(layerKey, keyToSet, layerToSet)
	if self.layers[keyToSet] then
		error(("Already inserted layer %q!"):format(keyToSet))
	end
	self:_checkOrError(layerToSet)
	local layer = self:_getLayerOrError(layerKey)

	for k in pairs(layerToSet) do
		self:_setDirty(k)
	end

	self:_createLayerAfter(layer, keyToSet, layerToSet)
end

function Data:_createLayerBefore(layer, keyToSet, layerToSet)
	layerToSet.__index = layer.__index
	self.layers[keyToSet] = setmetatable(layerToSet, layerToSet)
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

	local current = self.buffer.__index
	local selected
	while current do
		local currentPriority = rawget(current, PRIORITY) or 0
		if priority >= currentPriority then
			selected = current
			break
		end

		if current.__index then
			current = current.__index
		else
			break
		end
	end

	if selected then
		self:_createLayerAfter(selected, layerKey, layerToSet)
	elseif current then
		self:_createLayerBefore(current, layerKey, layerToSet)
	else
		self:_insert(layerKey, layerToSet)
	end
end

function Data:_set(layerKey, key, value)
	local layer = self.layers[layerKey]

	if rawget(layer, key) ~= value then
		layer[key] = value
		self:_setDirty(key)
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

return Data