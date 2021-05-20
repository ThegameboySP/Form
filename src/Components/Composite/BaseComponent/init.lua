local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Maid = require(script.Parent.Parent.Modules.Maid)
local Symbol = require(script.Parent.Parent.Modules.Symbol)

local ComponentsUtils = require(script.Parent.Parent.Shared.ComponentsUtils)
local NetworkMode = require(script.Parent.Parent.Shared.NetworkMode)
local UserUtils = require(script.Parent.User.UserUtils)
local FuncUtils = require(script.Parent.User.FuncUtils)
local Reducers = require(script.Parent.Parent.Shared.Reducers)
local SignalMixin = require(script.Parent.SignalMixin)
local TimeCycle = require(script.TimeCycle)
local makeSleep = require(script.makeSleep)
local runCoroutineOrWarn = require(script.Parent.runCoroutineOrWarn)

local KeypathSubscriptions = require(script.KeypathSubscriptions)
local StateMetatable = require(script.StateMetatable)
local Utils = require(script.Utils)

local Layers = require(script.Layers)
local Remote = require(script.Remote)
local Binding = require(script.Binding)
local Pause = require(script.Pause)

local BaseComponent = SignalMixin.wrap({
	NetworkMode = NetworkMode.ServerClient;
	BaseName = "BaseComponent";
	isServer = RunService:IsServer();
	isTesting = false;

	Maid = Maid;
	inst = UserUtils;
	util = ComponentsUtils;
	func = FuncUtils;
	player = Players.LocalPlayer;
	null = Symbol.named("null");

	getInterfaces = function()
		return {}
	end;
	mapConfig = nil;
	-- This should be run on each layer of state, then merged together.
	mapState = nil;

	bindToModule = function(module, module2)
		module2.Parent = module
		return require(module2)
	end;
	
	getBoundModule = function(instance, modName)
		local module = instance:FindFirstChild(modName) or instance.Parent:FindFirstChild(modName)
		if module == nil then
			error(("No module found: %s"):format(instance:GetFullName()))
		end
		return require(module)
	end;
})
BaseComponent.__index = BaseComponent

local RET = function(...) return ... end
local DESTROYED_ERROR = function()
	error("Cannot run a component that is destroyed!")
end

local op = function(def, func)
	return function(n)
		return function(c)
			if type(c) ~= "number" then
				c = def
			end
			return func(c, n)
		end
	end
end
BaseComponent.add = op(0, function(c, n) return c + n end)
BaseComponent.sub = op(0, function(c, n) return c - n end)
BaseComponent.mul = op(1, function(c, n) return c * n end)
BaseComponent.div = op(1, function(c, n) return c / n end)
BaseComponent.mod = op(0, function(c, n) return c % n end)

local function setStateMt(state)
	return setmetatable(state, StateMetatable)
end

function BaseComponent.new(ref)
	local self = SignalMixin.new(setmetatable({
		ref = ref;
		maid = Maid.new();
		externalMaid = Maid.new();
		
		config = {};
		state = setStateMt({});
		isDestroyed = false;

		_subscriptions = KeypathSubscriptions.new();
		_cycles = {};
	}, BaseComponent))

	self.sleep = makeSleep(self)
	self.Layers = Layers.new(self)
	self.Binding = Binding.new(self)
	self.Pause = Pause.new(self)
	if typeof(ref) == "Instance" then
		self.Remote = Remote.new(self)
	end

	self.maid:Add(function()
		self:Fire("Destroying")
		self:DisconnectAll()
		self.externalMaid:DoCleaning()

		self.Layers:Destroy()
		self.Binding:Destroy()
		self.Pause:Destroy()
		if self.Remote then
			self.Remote:Destroy()
		end
		
		self.PreInit = DESTROYED_ERROR
		self.Init = DESTROYED_ERROR
		self.Main = DESTROYED_ERROR

		self.isDestroyed = true
	end)

	return self
end


local function errored(_, comp)
	local prefix = ""
	if typeof(comp.ref) == "Instance" then
		prefix = comp.ref:GetFullName() .. ": "
	end

	return prefix .. "Component errored:\n%s\nTraceback: %s"
end


function BaseComponent:run(ref, config, state)
	local comp = self.new(ref)
	comp.Layers:Set(Symbol.named("base"), config, state)

	local ok = runCoroutineOrWarn(errored, comp.PreInit, comp)
		and runCoroutineOrWarn(errored, comp.Init, comp)
		and runCoroutineOrWarn(errored, comp.Main, comp)

	assert(ok, "Component errored, so could not continue.")

	comp.initialized = true
	return comp
end


function BaseComponent:extend(name)
	local newClass = setmetatable({
		BaseName = Utils.getBaseComponentName(name);
	}, BaseComponent)
	newClass.__index = newClass

	function newClass.new(ref, config)
		return setmetatable(self.new(ref, config), newClass)
	end

	return newClass
end


function BaseComponent:Destroy(...)
	self.maid:DoCleaning(...)
end


-- For registering events and component-specific initalization.
function BaseComponent:PreInit()
	-- pass
end


-- For accessing external things.
function BaseComponent:Init()
	-- pass
end


-- For firing events and setting into motion internal processes.
function BaseComponent:Main()
	-- pass
end


function BaseComponent:Reload()
	local layerKeys = self.Layers:getLayerKeys()
	local layers = self.Layers.layers

	local keyToMappedConfig = {}
	local oldConfig = self.config
	do
		local configFunc = self.mapConfig or RET
		local copyFunc = self.mapConfig and ComponentsUtils.deepCopy or RET

		local configLayers = {}
		for _, key in ipairs(layerKeys) do
			local layer = layers[key]
			if not next(layer.config) then continue end

			local mappedConfig = configFunc(copyFunc(layer.config))
			table.insert(configLayers, mappedConfig)
			keyToMappedConfig[key] = mappedConfig
		end

		self.config = Reducers.merge(configLayers)
	end

	if self.mapState then
		local stateLayers = {}

		for _, key in ipairs(layerKeys) do
			local layer = layers[key]
			if not next(layer.config) then continue end

			layers[key].state = self.mapState(
				keyToMappedConfig[key] or ComponentsUtils.deepCopy(layer.config),
				setStateMt(layers[key].state)
			)
			table.insert(stateLayers, key)
		end

		self.Layers:mergeStateLayers(stateLayers)
	end

	if self.initialized then
		self:Fire("Reloaded", ComponentsUtils.diff(self.config, oldConfig), oldConfig)
	end
end


do
	local fire = BaseComponent.Fire
	function BaseComponent:Fire(name, ...)
		local methodName = "On" .. name
		if type(self[methodName]) == "function" then
			self[methodName](self, ...)
		end

		fire(self, name, ...)
	end
end


function BaseComponent:_setFinalState(newState)
	local oldState = self.state
	self.state = setStateMt(newState)
	self._subscriptions:FireFromDelta(Utils.stateDiff(newState, oldState))
end


function BaseComponent:f(method)
	return function(...)
		return method(self, ...)
	end
end


function BaseComponent:SetState(delta)
	self.Layers:MergeState(Symbol.named("base"), delta)
end


function BaseComponent:SetConfig(config)
	self.Layers:SetConfig(Symbol.named("base"), config, nil)
end


function BaseComponent:SetLayer(config, state)
	self.Layers:Set(Symbol.named("base"), config, state)
end


function BaseComponent:GetState()
	return Utils.deepCopyState(self.state)
end


function BaseComponent:ConnectSubscribe(keypath, handler)
	return self._subscriptions:Subscribe(keypath, handler)
end


function BaseComponent:Subscribe(keypath, handler)
	return self.maid:Add(self:ConnectSubscribe(keypath, handler))
end


local function getStateByKeypath(state, keypath)
	local current = state
	for key in keypath:gmatch("([^.]+)%.?") do
		current = current[key]

		if current == nil then
			return nil
		end
	end

	return current
end

function BaseComponent:SubscribeAnd(keypath, handler)
	return (self.maid:Add(self:ConnectSubscribeAnd(keypath, handler)))
end


function BaseComponent:ConnectSubscribeAnd(keypath, handler)
	local disconnect = self:ConnectSubscribe(keypath, handler)
	local value = getStateByKeypath(self.state, keypath)
	if value ~= nil then
		handler(value)
	end
	
	return disconnect
end


function BaseComponent:FireAll(eventName, ...)
	self:Fire(eventName, ...)
	if self.Remote then
		self.Remote:FireAllClients(eventName, ...)
	end
end


function BaseComponent:Bind(event, handler)
	return self.maid:Add(event:Connect(handler))
end


function BaseComponent:GetTime()
	return self.man and self.man:GetTime() or tick()
end


function BaseComponent:SetCycle(name, cycleLen)
	local cycle = self._cycles[name]
	if cycle == nil then
		cycle = TimeCycle.new(cycleLen)
		self._cycles[name] = cycle
	else
		cycle:SetLength(cycleLen)
	end

	return cycle
end


function BaseComponent:GetCycle(name)
	return self._cycles[name]
end

return BaseComponent