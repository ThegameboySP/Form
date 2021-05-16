local Symbol = require(script.Parent.Parent.Parent.Modules.Symbol)
local Maid = require(script.Parent.Parent.Parent.Modules.Maid)
local StateMetatable = require(script.Parent.StateMetatable)
local Utils = require(script.Parent.Utils)

local Layers = {}
Layers.__index = Layers

local function setStateMt(state)
	return setmetatable(state, StateMetatable)
end

function Layers.new(base)
	return setmetatable({
		_base = base;
		_maid = Maid.new();

		_layers = {};
		_layerOrder = {};
	}, Layers)
end


function Layers:Destroy()
	self._maid:DoCleaning()
end


function Layers:Add(key, state)
	return self:_newComponentLayer(key, state, nil)
end


function Layers:Merge(key, delta)
	local layer = self._layers[key]

	if layer == nil then
		return self:Add(key, delta)
	else
		layer.state = setStateMt(Utils.deepMergeLayer(delta, layer.state))
		self:_updateState()
	end
end


function Layers:Remove(key)
	return self:_removeComponentLayer(key)
end


local RESERVED_LAYER_KEYS = {
	[Symbol.named("remote")] = true;
	[Symbol.named("base")] = true;
}
function Layers:_getLayers()
	local layersToMerge = {}
	for _, key in pairs({Symbol.named("remote"), Symbol.named("base")}) do
		if self._layers[key] then
			table.insert(layersToMerge, key)
		end
	end

	for _, layerKey in ipairs(self._layerOrder) do
		if RESERVED_LAYER_KEYS[layerKey] == nil then
			table.insert(layersToMerge, layerKey)
		end
	end

	return layersToMerge
end


function Layers:_mergeStateLayers(layerKeys)
	local newState = {}
	for _, key in ipairs(layerKeys) do
		Utils.deepMergeState(self._layers[key].state, newState)
	end
	
	for _, key in ipairs(layerKeys) do
		Utils.runStateFunctions(self._layers[key].state, newState)
	end

	self._base:_setFinalState(newState)
end


function Layers:_updateState()
	return self:_mergeStateLayers(self:_getLayers())
end


function Layers:_newComponentLayer(key, state, config)
	key = key or #self._layers + 1

	if self._layers[key] == nil then
		table.insert(self._layerOrder, key)
	end

	self._layers[key] = {
		state = setStateMt(Utils.deepCopyState(state or {}));
		config = config or {};
	}

	if config then
		self._source:Reload()
	else
		self:_updateState()
	end

	return key
end


function Layers:_removeComponentLayer(key)
	local layer = self._layers[key]
	if layer == nil then return end

	self._layers[key] = nil
	table.remove(self._layerOrder, table.find(self._layerOrder, key))

	if next(layer.config) then
		self._source:Reload()
	else
		self:_updateState()
	end
end

return Layers