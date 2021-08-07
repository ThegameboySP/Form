local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Maid = require(script.Parent.Parent.Modules.Maid)
local Symbol = require(script.Parent.Parent.Modules.Symbol)

local IComponentKeywords = require(script.IComponentKeywords)
local ComponentsUtils = require(script.Parent.Parent.Shared.ComponentsUtils)
local NetworkMode = require(script.Parent.Parent.Shared.NetworkMode)
local UserUtils = require(script.Parent.User.UserUtils)
local FuncUtils = require(script.Parent.User.FuncUtils)
local SignalMixin = require(script.Parent.SignalMixin)

local KeypathSubscriptions = require(script.KeypathSubscriptions)
local StateMetatable = require(script.StateMetatable)
local Utils = require(script.Utils)

local Layers = require(script.Layers)
local Remote = require(script.Remote)
local Binding = require(script.Binding)
local Pause = require(script.Pause)
local Sleep = require(script.Sleep)

local PASS = function() return true end

local embeddedClasses = setmetatable({
	Layers = Layers;
	Remote = Remote;
	Binding = Binding;
	Pause = Pause;
	Sleep = Sleep;
}, {__index = function(_, name)
	error(("No embedded component by name: %q"):format(name))
end})

local BaseComponent = SignalMixin.wrap({
	EmbeddedComponents = {"Layers"};
	NetworkMode = NetworkMode.ServerClient;
	BaseName = "BaseComponent";
	isServer = RunService:IsServer();
	isTesting = false;
	isComponent = true;

	IRef = PASS;
	IConfig = PASS;
	IState = PASS;

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

function BaseComponent.new(ref, keywords)
	assert(IComponentKeywords(keywords))
	local class = keywords.class

	local self = SignalMixin.new(setmetatable({
		BaseName = class.BaseName;
		
		ref = ref;
		maid = Maid.new();
		
		added = {};
		config = {};
		state = setmetatable({}, StateMetatable);
		isDestroyed = false;
		isInitialized = false;

		_subscriptions = KeypathSubscriptions.new();
	}, class))

	do
		local ok, err = self.IRef(self.ref)
		if not ok then
			error(("Invalid reference: %s"):format(err or ""))
		end
	end

	local added = {}
	local embedded = class.EmbeddedComponents
	local dict = ComponentsUtils.arrayToHash(embedded)
	for _, name in pairs(embedded) do
		local embeddedClass = embeddedClasses[name]
		if embeddedClass.Required then
			for _, requiredName in pairs(embeddedClass.Required) do
				if dict[requiredName] == nil then
					error(("Embedded component %s requires %s, but it isn't defined in class!"):format(name, requiredName))
				end
			end
		end
		
		local resolvedName = embeddedClass.Name or name
		self[resolvedName] = self.maid:Add(embeddedClass.new(self))
		added[embeddedClass] = self[resolvedName]
	end

	for embeddedClass, obj in pairs(added) do
		if embeddedClass.Init then
			embeddedClass.Init(obj, keywords)
		end
	end

	return self
end


function BaseComponent:registerEmbeddedComponent(class)
	if rawget(embeddedClasses, class) then
		error(("Already registered %q!"):format(class.ClassName))
	end
	embeddedClasses[class.ClassName] = class
end


function BaseComponent:run(ref, keywords)
	local comp = self.new(ref, keywords)
	comp:Start()
	return comp, Symbol.named("base")
end


function BaseComponent:extend(name, structure)
	structure = structure or {}
	structure.BaseName = Utils.getBaseComponentName(name)

	local newClass = setmetatable(structure, BaseComponent)
	newClass.__index = newClass

	function newClass.new(ref, keywords)
		keywords = keywords or {}
		keywords.class = keywords.class or newClass
		return self.new(ref, keywords)
	end

	return newClass
end


function BaseComponent:Destroy(...)
	self:Fire("Destroying")
	self.maid:DoCleaning(...)

	if self.Layers then
		self.Layers:Destroy()
	end
	if self.Binding then
		self.Binding:Destroy()
	end
	if self.Pause then
		self.Pause:Destroy()
	end
	if self.Remote then
		self.Remote:Destroy()
	end
	
	self.PreInit = DESTROYED_ERROR
	self.Init = DESTROYED_ERROR
	self.Main = DESTROYED_ERROR

	self.isDestroyed = true
	self:Fire("Destroyed")
	self:DisconnectAll()
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


function BaseComponent:Start()
	if self.isInitialized then return end

	coroutine.wrap(self.PreInit)(self)
	coroutine.wrap(self.Init)(self)
	coroutine.wrap(self.Main)(self)

	self.isInitialized = true
end


do
	local fire = BaseComponent.Fire
	function BaseComponent:Fire(key, ...)
		if type(key) == "string" then
			local methodName = "On" .. key
			if type(self[methodName]) == "function" then
				self[methodName](self, ...)
			end
		end

		fire(self, key, ...)
	end
end


function BaseComponent:f(method, ...)
	local args = table.pack(...)
	return function(...)
		return method(self, table.unpack(args, 1, args.n), ...)
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


function BaseComponent:SubscribeAnd(keypath, handler)
	local disconnect = self:Subscribe(keypath, handler)
	local value = self.state:getByKeyPath(keypath)
	if value ~= nil then
		handler(value)
	end
	
	return (self.maid:AddAuto(disconnect))
end


-- Creates a new component out of the class and keywords and assigns it,
-- but doesn't start it. Errors if the class is already added.
function BaseComponent:PreStartComponent(class, keywords)
	assert(not self.added[class], "Cannot add a class which already is already added!")
	keywords = keywords or {}

	keywords.class = class
	local comp = class.new(keywords.target or self, keywords)
	comp.man = self.man
	Layers.setLayersFromKeywords(comp, keywords)

	self:Fire("ComponentAdding", comp, keywords.config or {})
	self.added[class] = comp
	
	local maidId = self.maid:GiveTask(comp)
	comp:On("Destroying", function()
		self.maid:Remove(maidId)
		self.added[class] = nil
		self:Fire("ComponentRemoved", comp)
	end)

	return comp, Symbol.named("base")
end


-- Creates a new component out of the class and keywords and assigns it,
-- then starts it. If the component already exists, adds layers.
function BaseComponent:GetOrAddComponent(class, keywords)
	keywords = keywords or {}

	if self.added[class] == nil then
		local comp, id = self:PreStartComponent(class, keywords)
		comp:Start()
		self:Fire("ComponentAdded", comp, keywords.config or {})
		return comp, id
	end

	local comp = self.added[class]
	Layers.setLayersFromKeywords(comp, keywords)

	if keywords.config then
		local id = comp.Layers:NewId()
		comp.Layers:SetConfig(id, keywords.config)
		return comp, id
	end

	return comp
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

return BaseComponent