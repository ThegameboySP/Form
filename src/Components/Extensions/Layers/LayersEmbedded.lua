local Ops = require(script.Parent.Ops)
local Hooks = require(script.Parent.Parent.Parent.Form.Hooks)
local Symbol = require(script.Parent.Parent.Parent.Modules.Symbol)
local Constants = require(script.Parent.Parent.Parent.Form.Constants)

local Layers = {}
Layers.Ops = Ops
Layers.__index = Layers

local Object = {}
Object.__index = Object
Object.__mode = "v"

function Object.new(data, key)
	return setmetatable({
		_data = data or error("Layers required");
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
local BLANK = table.freeze({})

local bufferOrder = {}

local bufferMt = {
	__index = function(self, key)
		local resolved = self.__index[key]

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

function Layers.new(extension, checkers, defaults)
	return setmetatable({
		_extension = extension;
		_checkers = checkers;
		
		buffer = setmetatable({
			__index = defaults or BLANK;
		}, bufferMt);
		layers = {};
		set = {};
		_delta = {};
		_objects = nil;

		_subscriptions = nil;
	}, Layers)
end

function Layers:Destroy()
	if self._subscriptions then
		self._subscriptions:Destroy()
		self._subscriptions = nil
	end
	
	self.buffer.__index = nil
	self.buffer = nil
	self.layers = nil
	self.set = nil
	self._delta = nil
	self._objects = nil
end

function Layers:_createSubscriptionsIfNil()
	if self._subscriptions == nil then
		self._subscriptions = Hooks.new()
	end

	return self._subscriptions
end

-- Subscribes to next subscription update for key.
function Layers:On(key, handler)
	return self:_createSubscriptionsIfNil():On(key, handler)
end

-- Subscribes to next subscription update.
function Layers:OnAll(handler)
	return self:_createSubscriptionsIfNil():On(ALL, handler)
end

-- Subscribes to next subscription update for key.
-- If the key currently is non-nil, calls it immediately.
function Layers:For(key, handler)
	local currentValue = self.buffer[key]
	if currentValue ~= nil then
		local oldValue = self._delta[key]
		handler(currentValue, if oldValue == NONE then nil else oldValue)
	end

	return self:_createSubscriptionsIfNil():On(key, handler)
end

-- Subscribes to next subscription update.
-- If current data is not empty, calls it immediately, but the "old" parameter *is nil*.
function Layers:ForAll(handler)
	local current = {}
	for k in pairs(self.set) do
		current[k] = self.buffer[k]
	end

	if next(current) then
		handler(current, nil)
	end

	return self:_createSubscriptionsIfNil():On(ALL, handler)
end

function Layers:onUpdate()
	if self._subscriptions == nil then return end
	-- Destroyed
	if self.buffer == nil then return end

	local subscriptions = self._subscriptions
	local buffer = self.buffer

	for k, oldValue in pairs(self._delta) do
		if subscriptions[k] == nil then continue end

		local current = buffer[k]
		if current == nil then
			self.set[k] = nil
		end

		oldValue = if oldValue == NONE then nil else oldValue
		if current ~= oldValue then
			subscriptions:Fire(k, current, oldValue)
		end
	end

	if subscriptions[ALL] then
		local current = {}

		for k in pairs(self._delta) do
			current[k] = buffer[k]
		end

		subscriptions:Fire(ALL, current, self._delta)

		self._delta = {}
	else
		table.clear(self._delta)
	end
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

function Layers:_setDirty(k)
	if self._delta[k] == nil then
		local value = self.buffer[k]
		self._delta[k] = if value == nil then NONE else value
	end

	self.buffer[k] = nil
	self.set[k] = true
	self._extension.pending[self] = true
end

function Layers:_checkOrError(toCheck)
	if self._checkers then
		for k, v in pairs(toCheck) do
			checkOrError(self._checkers[k], k, v)
		end
	end
end

function Layers:_getLayerOrError(layerKey)
	local layer = self.layers[layerKey]
	if layer == nil then
		error(("No layer by key %q!"):format(layerKey))
	end

	return layer
end

function Layers:NewId()
	return #self.layers + 1
end

function Layers:_rawInsert(key, layerToSet)
	local top = self.buffer.__index
	if top then
		layerToSet.__index = top
	end

	self.layers[key] = setmetatable(layerToSet, layerToSet)
	self.buffer.__index = layerToSet

	return layerToSet
end

function Layers:_insert(key, layerToSet)
	self:_checkOrError(layerToSet)

	for k in pairs(layerToSet) do
		self:_setDirty(k)
	end

	return self:_rawInsert(key, layerToSet)
end

function Layers:InsertIfNil(key)
	local layer = self.layers[key]
	if layer == nil then
		return self:_insert(key, {})
	end

	return layer
end

function Layers:RemoveLayer(layerKey)
	local layer = self.layers[layerKey]
	if layer == nil then return end

	for k in pairs(layer) do
		if k == "__index" then continue end
		self:_setDirty(k)
	end

	getPrevious(self.buffer, layer).__index = layer.__index
end

function Layers:SetLayer(layerKey, layerToSet)
	local existingLayer = self.layers[layerKey]

	if existingLayer then
		self:_checkOrError(layerToSet)

		for k in pairs(layerToSet) do
			self:_setDirty(k)
		end

		for k in pairs(existingLayer) do
			if k == "__index" then continue end
			self:_setDirty(k)
		end

		layerToSet.__index = existingLayer.__index
		layerToSet[PRIORITY] = existingLayer[PRIORITY]
		getPrevious(self.buffer, existingLayer).__index = layerToSet
		self.layers[layerKey] = setmetatable(layerToSet, layerToSet)
	else
		self:_insert(layerKey, layerToSet)
	end
end

function Layers:_createLayerAfter(at, keyToSet, layerToSet)
	layerToSet.__index = at
	self.layers[keyToSet] = setmetatable(layerToSet, layerToSet)
	getPrevious(self.buffer, at).__index = layerToSet
end

function Layers:CreateLayerAfter(layerKey, keyToSet, layerToSet)
	if self.layers[keyToSet] then
		error(("Already inserted layer %q!"):format(keyToSet))
	end
	self:_checkOrError(layerToSet)
	local layer = self:_getLayerOrError(layerKey)

	for k in pairs(layerToSet) do
		self:_setDirty(k)
	end

	self:_createLayerAfter(layer, keyToSet, layerToSet)
	layerToSet[PRIORITY] = layer[PRIORITY]
end

function Layers:_createLayerBefore(at, keyToSet, layerToSet)
	-- Hacky way to detect if layer is Defaults.
	if table.isfrozen(at) then
		return self:_createLayerAfter(at, keyToSet, layerToSet)
	end

	layerToSet.__index = at.__index
	self.layers[keyToSet] = setmetatable(layerToSet, layerToSet)
	at.__index = layerToSet
end

function Layers:CreateLayerBefore(layerKey, keyToSet, layerToSet)
	if self.layers[keyToSet] then
		error(("Already inserted layer %q!"):format(keyToSet))
	end
	self:_checkOrError(layerToSet)
	local layer = self:_getLayerOrError(layerKey)

	for k in pairs(layerToSet) do
		self:_setDirty(k)
	end

	self:_createLayerBefore(layer, keyToSet, layerToSet)
	layerToSet[PRIORITY] = layer[PRIORITY]
end

function Layers:CreateLayerAtPriority(layerKey, priority, layerToSet)
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
		if priority >= (rawget(current, PRIORITY) or 0) then
			selected = current
			break
		end

		if current.__index then
			current = current.__index
		else
			break
		end
	end

	-- Found a layer that has a lower priority:
	if selected then
		self:_createLayerAfter(selected, layerKey, layerToSet)
	-- All layers were higher priority:
	elseif current then
		self:_createLayerBefore(current, layerKey, layerToSet)
	-- No layers:
	else
		self:_insert(layerKey, layerToSet)
	end
end

function Layers:_set(layerKey, key, value)
	local layer = self.layers[layerKey]

	if rawget(layer, key) ~= value then
		self:_setDirty(key)
		layer[key] = value
	end
end

function Layers:Set(layerKey, key, value)
	if self._checkers and value ~= nil then
		checkOrError(self._checkers[key], key, value)
	end

	self:_set(layerKey, key, value)
end

function Layers:MergeLayer(layerKey, delta)
	self:_checkOrError(delta)
	
	for key, value in pairs(delta) do
		if value == NONE then
			self:_set(layerKey, key, nil)
		else
			self:_set(layerKey, key, value)
		end
	end
end

function Layers:GetObject(key)
	if self._objects == nil then
		self._objects = {}
	elseif self._objects[key] then
		return self._objects[key]
	end

	local object = Object.new(self, key)
	self._objects[key] = object

	return object
end

return Layers