local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Maid = require(script.Parent.Parent.Modules.Maid)
local Symbol = require(script.Parent.Parent.Modules.Symbol)
local t = require(script.Parent.Parent.Modules.t)

local ComponentsUtils = require(script.Parent.Parent.Shared.ComponentsUtils)
local NetworkMode = require(script.Parent.Parent.Shared.NetworkMode)
local UserUtils = require(script.Parent.User.UserUtils)
local FuncUtils = require(script.Parent.User.FuncUtils)
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
	mapConfig = function(...) return ... end;
	-- This should be run on each layer of state, then merged together.
	mapState = function() return {} end;

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

local PASS = function() return true end
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

function BaseComponent.new(ref)
	local self = SignalMixin.new(setmetatable({
		ref = ref;
		maid = Maid.new();
		externalMaid = Maid.new();
		
		config = {};
		state = setmetatable({}, StateMetatable);
		isDestroyed = false;
		initialized = false;

		_subscriptions = KeypathSubscriptions.new();
		_cycles = {};
		_componentsByClass = {};
	}, BaseComponent))

	self.sleep = makeSleep(self)

	self.Layers = Layers.new(self)
	self.Layers:On("Resolved", function(resolvedConfig, resolvedState)
		local old = self.config
		self.config = resolvedConfig or self.config

		if self.initialized and resolvedConfig then
			local diff = ComponentsUtils.diff(resolvedConfig, old)
			self:Fire("NewConfig", diff, old)
		end

		-- Fire state update last so that :OnNewConfig() has a chance to do something to internal state first.
		local oldState = self.state
		self.state = setmetatable(resolvedState, StateMetatable)
		self._subscriptions:FireFromDelta(Utils.stateDiff(resolvedState, oldState))
	end)

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
	self:cache()
	do
		local ok, err = self.IRef(ref)
		if not ok then
			error(("Invalid reference: %s"):format(err or ""))
		end
	end

	local comp = self.new(ref)
	comp.Layers:Set(Symbol.named("base"), config, state)

	local ok = runCoroutineOrWarn(errored, comp.PreInit, comp)
		and runCoroutineOrWarn(errored, comp.Init, comp)
		and runCoroutineOrWarn(errored, comp.Main, comp)

	assert(ok, "Component errored, so could not continue.")

	comp.initialized = true
	return comp, Symbol.named("base")
end


function BaseComponent:extend(name)
	local newClass = setmetatable({
		BaseName = Utils.getBaseComponentName(name);
		[Symbol.named("cached")] = false;
	}, BaseComponent)
	newClass.__index = newClass

	function newClass.new(ref)
		return setmetatable(self.new(ref), newClass)
	end

	return newClass
end


function BaseComponent:cache()
	if self[Symbol.named("cached")] then return end

	local interfaces = self.getInterfaces(t)
	self.IRef = interfaces.IRef or PASS
	self.IConfig = interfaces.IConfig or PASS
	self.IState = interfaces.IState or PASS

	self[Symbol.named("cached")] = true
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


function BaseComponent:GetOrAddComponent(class, name, config, state)
	if self[name] == nil then
		local ret = table.pack(class:run(self, config, state))
		local comp = ret[1]
		local id = self.maid:GiveTask(comp)
		self._componentsByClass[class] = comp

		self[name] = comp
		comp:On("Destroying", function()
			self.maid:Remove(id)
			self[name] = nil
			self._componentsByClass[class] = nil
		end)

		return table.unpack(ret, 1, ret.n)
	end

	local comp = self[name]
	local id = #comp.Layers:get() + 1
	comp.Layers:Set(id, config, state)
	return comp, id
end


function BaseComponent:RemoveComponent(class, ...)
	local comp = self._componentsByClass[class]
	if comp == nil then return end
	comp:Destroy(...)
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