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
		
		added = {};
		config = {};
		state = setmetatable({}, StateMetatable);
		isDestroyed = false;
		initialized = false;

		_subscriptions = KeypathSubscriptions.new();
		_cycles = {};
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


function BaseComponent:run(ref, config, state)
	local comp = self.new(ref)
	return comp, comp:Start(config, state)
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


function BaseComponent.cache(class)
	if class[Symbol.named("cached")] then return end

	local interfaces = class.getInterfaces(t)
	class.IRef = interfaces.IRef or PASS
	class.IConfig = interfaces.IConfig or PASS
	class.IState = interfaces.IState or PASS

	class[Symbol.named("cached")] = true
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


function BaseComponent:GetClass()
	return getmetatable(self)
end


function BaseComponent:Start(config, state)
	self.cache(self:GetClass())
	do
		local ok, err = self.IRef(self.ref)
		if not ok then
			error(("Invalid reference: %s"):format(err or ""))
		end
	end

	self.Layers:Set(Symbol.named("base"), config, state)

	coroutine.wrap(self.PreInit)(self)
	coroutine.wrap(self.Init)(self)
	coroutine.wrap(self.Main)(self)

	self.initialized = true
	return Symbol.named("base")
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


function BaseComponent:Subscribe(keypath, handler)
	return (self.maid:AddAuto(self._subscriptions:Subscribe(keypath, handler)))
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
	local disconnect = self:Subscribe(keypath, handler)
	local value = getStateByKeypath(self.state, keypath)
	if value ~= nil then
		handler(value)
	end
	
	return (self.maid:AddAuto(disconnect))
end


function BaseComponent:GetOrAddComponent(class, config, state)
	if self.added[class] == nil then
		local comp = class.new(self)
		comp.man = self.man
		local ret = table.pack(comp:Start(config, state))
		
		local id = self.maid:GiveTask(comp)

		comp:On("Destroying", function()
			self.maid:Remove(id)
			self.added[class] = nil
			self:Fire("ComponentRemoved", comp)
		end)

		self.added[class] = comp
		self:Fire("ComponentAdded", comp)
		return comp, table.unpack(ret, 1, ret.n)
	end

	local comp = self.added[class]
	local id = #comp.Layers:get() + 1
	comp.Layers:Set(id, config, state)
	return comp, id
end


function BaseComponent:RemoveComponent(class, ...)
	local comp = self.added[class]
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