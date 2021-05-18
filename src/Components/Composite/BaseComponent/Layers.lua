local Symbol = require(script.Parent.Parent.Parent.Modules.Symbol)
local Maid = require(script.Parent.Parent.Parent.Modules.Maid)
local Utils = require(script.Parent.Utils)

local Layers = {}
Layers.__index = Layers

function Layers.new(base)
	return setmetatable({
		_base = base;
		_maid = Maid.new();

		layers = {};
		_layerOrder = {};
	}, Layers)
end


function Layers:Destroy()
	self._maid:DoCleaning()
end


function Layers:SetState(key, state)
	return self:Set(key, nil, state)
end


function Layers:MergeState(key, delta)
	local layer = self.layers[key]

	if layer == nil then
		return self:SetState(key, delta)
	else
		layer.state = Utils.deepMergeLayer(delta, layer.state)
		self:_updateState()
	end
end


function Layers:RemoveState(key)
	return self:Remove(key)
end


local RESERVED_LAYER_KEYS = {
	[Symbol.named("remote")] = true;
	[Symbol.named("base")] = true;
}
function Layers:getLayerKeys()
	local layersToMerge = {}
	for _, key in pairs({Symbol.named("remote"), Symbol.named("base")}) do
		if self.layers[key] then
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


function Layers:mergeStateLayers(layerKeys)
	local newState = {}
	for _, key in ipairs(layerKeys) do
		Utils.deepMergeState(self.layers[key].state, newState)
	end
	
	for _, key in ipairs(layerKeys) do
		Utils.runStateFunctions(self.layers[key].state, newState)
	end

	self._base:_setFinalState(newState)
end


function Layers:_updateState()
	return self:mergeStateLayers(self:getLayerKeys())
end


function Layers:SetConfig(key, config)
	return self:Set(key, config, nil)
end


function Layers:_insertIfNil(key)
	if self.layers[key] == nil then
		table.insert(self._layerOrder, key)
		self.layers[key] = {state = {}, config = {}}
	end

	return self.layers[key]
end


function Layers:Set(key, config, state)
	local layer = self:_insertIfNil(key)
	if config and next(config) then
		layer.config = config
	end

	if state and next(state) then
		layer.state = state
	end

	if config and next(config) then
		self._base:Reload()
	else
		self:_updateState()
	end

	return layer
end


function Layers:Remove(key)
	local layer = self.layers[key]
	if layer == nil then return end

	self.layers[key] = nil
	table.remove(self._layerOrder, table.find(self._layerOrder, key))

	-- If we're all out of layers, the component is empty. Destroy.
	if self._layerOrder[1] == nil then
		self._base:Destroy()
		return
	end

	if next(layer.config) then
		self._base:Reload()
	else
		self:_updateState()
	end
end

return Layers