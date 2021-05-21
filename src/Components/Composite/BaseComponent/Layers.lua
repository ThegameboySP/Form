local Symbol = require(script.Parent.Parent.Parent.Modules.Symbol)
local ComponentsUtils = require(script.Parent.Parent.Parent.Shared.ComponentsUtils)
local Reducers = require(script.Parent.Parent.Parent.Shared.Reducers)
local StateMetatable = require(script.Parent.StateMetatable)
local SignalMixin = require(script.Parent.Parent.SignalMixin)
local Maid = require(script.Parent.Parent.Parent.Modules.Maid)
local Utils = require(script.Parent.Utils)

local function setStateMt(state)
	return setmetatable(state, StateMetatable)
end

local Layers = SignalMixin.wrap({})
Layers.__index = Layers

function Layers.new(base)
	return SignalMixin.new(setmetatable({
		_base = base;
		_maid = Maid.new();

		_layers = {};
		_layerOrder = {};
	}, Layers))
end


function Layers:Destroy()
	self._maid:DoCleaning()
end


function Layers:get()
	return self._layers
end


function Layers:NewId()
	return #self._layers + 1
end


function Layers:SetState(key, state)
	return self:Set(key, nil, state)
end


function Layers:MergeState(key, delta)
	local layer = self._layers[key]

	if layer == nil then
		return self:SetState(key, delta)
	else
		local newState = Utils.deepMergeLayer(delta, layer.state)
		self:Set(key, nil, newState)
	end
end


function Layers:RemoveState(key)
	return self:Remove(key)
end


local RESERVED_LAYER_KEYS = {
	[Symbol.named("remote")] = true;
	[Symbol.named("base")] = true;
}
function Layers:_getLayerKeys()
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


function Layers:SetConfig(key, config)
	return self:Set(key, config, nil)
end


function Layers:_insertIfNil(key)
	if self._layers[key] == nil then
		table.insert(self._layerOrder, key)
		self._layers[key] = {state = {}, config = {}}
	end

	return self._layers[key]
end


function Layers:Set(key, config, state)
	local layer = self:_insertIfNil(key)
	-- If no config or state, no change must take place, and we don't want to
	-- run .mapState on a default configuration. Return early.
	if config == nil and state == nil then return end

	self:_resolve(key, config, state)
	return layer
end


function Layers:Remove(key)
	local layer = self._layers[key]
	if layer == nil then return end

	self._layers[key] = nil
	table.remove(self._layerOrder, table.find(self._layerOrder, key))

	-- If we're all out of layers, the component is empty. Destroy.
	if self._layerOrder[1] == nil then
		self._base:Destroy()
		return
	end

	self:_resolve(key, {}, {})
end


function Layers:_resolveConfig(configs)
	local map = self._base.mapConfig
	local configLayers = {}
	for _, config in ipairs(configs) do
		local mappedConfig = ComponentsUtils.deepMerge(
			map(ComponentsUtils.deepCopy(config)),
			config
		)
		table.insert(configLayers, mappedConfig)
	end

	return configLayers
end


function Layers:_resolveState(states, configs)
	local map = self._base.mapState
	local stateLayers = {}

	for index, state in ipairs(states) do
		local config = configs[index]
		table.insert(stateLayers, Utils.deepMergeLayer(map(
			ComponentsUtils.deepCopy(config),
			setStateMt(state)
		), state))
	end

	return stateLayers
end


local function reduceStateLayers(layers)
	local reduced = {}
	for _, layer in ipairs(layers) do
		Utils.deepMergeState(layer, reduced)
	end

	return reduced
end

function Layers:_resolve(changedKey, config, state)
	local layers = self._layers

	if config then
		local ok, err = self._base.IConfig(config)
		if not ok then
			error(("Invalid configuration for layer %q: %s"):format(tostring(changedKey), err))
		end
	end

	if state then
		local ok, err = self._base.IState(state)
		if not ok then
			error(("Invalid state for layer %q: %s"):format(tostring(changedKey), err))
		end
	end
	
	local layerKeys = self:_getLayerKeys()
	local configs = {}
	local states = {}
	for _, key in ipairs(layerKeys) do
		local layerConfig = layers[key].config
		local layerState = layers[key].state

		if key == changedKey then
			layerConfig = config or layerConfig
			layerState = state or layerState
		end

		table.insert(configs, layerConfig)
		table.insert(states, layerState)
	end
	
	local resolvedConfig, resolvedConfigLayers
	if config then
		resolvedConfigLayers = self:_resolveConfig(configs)
		resolvedConfig = Reducers.merge(resolvedConfigLayers)
		for index, key in ipairs(layerKeys) do
			layers[key].config = configs[index]
		end

		local ok, err = self._base.IConfig(resolvedConfig)
		if not ok then
			error(("Invalid reduced configuration: %s"):format(err))
		end
	else
		resolvedConfigLayers = configs
	end

	local resolvedState do
		local stateLayers = self:_resolveState(states, resolvedConfigLayers)
		resolvedState = reduceStateLayers(stateLayers)
		for index, key in ipairs(layerKeys) do
			layers[key].state = stateLayers[index]
		end

		for _, key in ipairs(layerKeys) do
			Utils.runStateFunctions(layers[key].state, resolvedState)
		end

		local ok, err = self._base.IState(resolvedState)
		if not ok then
			error(("Invalid reduced state: %s"):format(err))
		end
	end

	self:Fire("Resolved", resolvedConfig, resolvedState)
end

return Layers