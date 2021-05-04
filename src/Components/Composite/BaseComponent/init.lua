local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Maid = require(script.Parent.Parent.Modules.Maid)
local Event = require(script.Parent.Parent.Modules.Event)
local Symbol = require(script.Parent.Parent.Modules.Symbol)
local bp = require(script.Parent.Parent.Modules.bp)
local ComponentsUtils = require(script.Parent.Parent.Shared.ComponentsUtils)
local NetworkMode = require(script.Parent.Parent.Shared.NetworkMode)
local UserUtils = require(script.Parent.User.UserUtils)
local FuncUtils = require(script.Parent.User.FuncUtils)

local KeypathSubscriptions = require(script.Parent.KeypathSubscriptions)
local StateMetatable = require(script.StateMetatable)
local Utils = require(script.Utils)

local BaseComponent = {}
BaseComponent.ComponentName = "BaseComponent"
BaseComponent.BaseName = "BaseComponent"
BaseComponent.isTesting = false
BaseComponent.__index = BaseComponent

local IS_SERVER = RunService:IsServer()
local ON_SERVER_ERROR = "Can only be called on the server!"
local NO_REMOTE_ERROR = "No remote event under %s by name %s!"
local NOOP = function() end

BaseComponent.NetworkMode = NetworkMode.ServerClient
BaseComponent.Maid = Maid
BaseComponent.inst = UserUtils
BaseComponent.util = ComponentsUtils
BaseComponent.func = FuncUtils
BaseComponent.isServer = IS_SERVER
BaseComponent.player = Players.LocalPlayer
BaseComponent.null = Symbol.named("null")

local op = function(func)
	return function(n)
		return function(c)
			return func(c, n)
		end
	end
end
BaseComponent.add = op(function(c, n) return (c or 0) + n end)
BaseComponent.sub = op(function(c, n) return (c or 0) - n end)
BaseComponent.mul = op(function(c, n) return (c or 0) * n end)
BaseComponent.div = op(function(c, n) return (c or 0) / n end)

local function setStateMt(state)
	return setmetatable(state, StateMetatable)
end

function BaseComponent.getInterfaces()
	return {}
end

function BaseComponent.new(instance, config)
	local self = setmetatable({
		instance = instance;
		maid = Maid.new();
		
		config = config;
		state = setStateMt({});

		_events = {};
		_listeners = {};
		_layers = {};
		_layerOrder = {};
		_subscriptions = KeypathSubscriptions.new();
	}, BaseComponent)

	self:registerEvents("Destroying")

	return self
end


local function transform(comp, config, state)
	local newState = {}
	if comp.mapConfig then
		config = config
	end

	-- When reloading, this should be run on each layer of state, then merged together.
	-- When calling :newLayer, state is equal to the union of all state.
	-- When calling :start(), state is an empty table.
	if comp.mapState then
		newState = setStateMt(comp.mapState(config, state))
	end

	return config, newState
end


function BaseComponent:start(instance, config)
	local comp = self.new(instance, config)
	local newConfig, newState = transform(comp, comp.config, setStateMt({}))
	self.config = newConfig
	comp:addLayer(Symbol.named("base"), newState)

	comp:PreInit()
	comp:Init()
	comp:Main()

	return comp
end


function BaseComponent.bindToModule(module, module2)
	module2.Parent = module
	return require(module2)
end


function BaseComponent.getBoundModule(instance, modName)
	local module = instance:FindFirstChild(modName) or instance.Parent:FindFirstChild(modName)
	if module == nil then
		error(("No module found: %s"):format(instance:GetFullName()))
	end
	return require(module)
end


function BaseComponent:extend(name)
	local newClass = setmetatable({
		ComponentName = name;
		BaseName = ComponentsUtils.getBaseComponentName(name);
	}, BaseComponent)
	newClass.__index = newClass

	function newClass.new(instance, config)
		return setmetatable(self.new(instance, config), newClass)
	end

	return newClass
end


-- isReloading: bool?
function BaseComponent:Destroy()
	self.maid:DoCleaning()
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


function BaseComponent:reload(config)
	self:Destroy(true)

	self.config, self.state = transform(self, config or self.config, self.state)

	self:PreInit()
	self:Init()
	self:Main()
end


function BaseComponent:f(method)
	return function(...)
		return method(self, ...)
	end
end


function BaseComponent:addLayer(key, state)
	if self._layers[key] == nil then
		table.insert(self._layerOrder, key)
	end

	self._layers[key] = Utils.deepCopyState(state)
	self:_updateState()
end
BaseComponent.AddLayer = BaseComponent.addLayer


function BaseComponent:mergeLayer(key, delta)
	local layer = self._layers[key]

	if layer == nil then
		return self:addLayer(key, delta)
	else
		self._layers[key] = Utils.deepMergeLayer(delta, layer)
		self:_updateState()
	end
end
BaseComponent.MergeLayer = BaseComponent.mergeLayer


function BaseComponent:removeLayer(key)
	if self._layers[key] == nil then return end

	self._layers[key] = nil
	table.remove(self._layerOrder, table.find(self._layerOrder, key))

	self:_updateState()
end
BaseComponent.RemoveLayer = BaseComponent.removeLayer


local RESERVED_LAYER_KEYS = {
	[Symbol.named("remote")] = true;
	[Symbol.named("base")] = true;
}
function BaseComponent:_updateState()
	local layersToMerge = {self._layers[Symbol.named("remote")]}
	table.insert(layersToMerge, self._layers[Symbol.named("base")])

	for _, layerKey in ipairs(self._layerOrder) do
		if RESERVED_LAYER_KEYS[layerKey] == nil then
			table.insert(layersToMerge, self._layers[layerKey])
		end
	end

	local newState = {}
	for _, layer in ipairs(layersToMerge) do
		Utils.deepMergeState(layer, newState)
	end
	
	for _, layer in ipairs(layersToMerge) do
		Utils.runStateFunctions(layer, newState)
	end

	local oldState = self.state
	self.state = setStateMt(newState)

	self._subscriptions:FireFromDelta(Utils.stateDiff(newState, oldState))
end


function BaseComponent:setState(delta)
	return self:mergeLayer(Symbol.named("base"), delta)
end
BaseComponent.SetState = BaseComponent.setState


function BaseComponent:getState()
	return Utils.deepCopyState(self.state)
end
BaseComponent.GetState = BaseComponent.getState


function BaseComponent:subscribe(keypath, handler)
	local disconnect = self._subscriptions:Subscribe(keypath, handler)
	return self.maid:Add(disconnect)
end
BaseComponent.Subscribe = BaseComponent.subscribe


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

function BaseComponent:subscribeAnd(keypath, handler)
	local disconnect = self:subscribe(keypath, handler)
	local value = getStateByKeypath(self.state, keypath)
	if value ~= nil then
		handler(value)
	end
	
	return disconnect
end
BaseComponent.SubscribeAnd = BaseComponent.subscribeAnd

function BaseComponent:registerEvents(...)
	for k, v in next, {...} do
		local event = Event.new()
		
		if type(v) == "function" then
			self._events[k] = event
			event:Connect(v)
		elseif type(v) == "string" then
			self._events[v] = event
		end
	end
end


function BaseComponent:on(name, handler)
	self._listeners[name] = self._listeners[name] or {}
	local listeners = self._listeners[name]
	table.insert(listeners, handler)

	return function()
		local i = table.find(listeners, handler)
		if i == nil then return end
		table.remove(listeners, i)
	end
end


function BaseComponent:fire(name, ...)
	local listeners = self._listeners[name]
	if listeners == nil then return end

	for _, handler in ipairs(listeners) do
		local co = coroutine.create(handler)
		local ok, err = coroutine.resume(co, ...)

		if not ok then
			warn(("Listener errored at %s\n%s"):format(debug.traceback(co), err))
		end
	end
end


function BaseComponent:fireEvent(eventName, ...)
	self._events[eventName]:Fire(...)
end


function BaseComponent:connectEvent(eventName, handler)
	return self._events[eventName]:Connect(handler)
end
BaseComponent.ConnectEvent = BaseComponent.connectEvent


function BaseComponent:hasEvent(eventName)
	return self._events[eventName] ~= nil
end
BaseComponent.HasEvent = BaseComponent.hasEvent


function BaseComponent:fireAll(eventName, ...)
	self:fireEvent(eventName, ...)
	self:fireAllClients(eventName, ...)
end


function BaseComponent:registerRemoteEvents(...)
	assert(self.isServer, ON_SERVER_ERROR)

	local folder = getOrMakeRemoteEventFolder(self.instance, self.BaseName)
	for k, v in next, {...} do
		local remote = Instance.new("RemoteEvent")

		if type(v) == "function" then
			remote.Name = tostring(k)
			self:bindRemoteEvent(remote.Name, v)
		elseif type(v) == "string" then
			remote.Name = v
		end

		remote.Parent = folder
	end

	folder:SetAttribute("Loaded", true)
end


function BaseComponent:_getRemoteEventSchema(func)
	return bp.new(self.instance, {
		[bp.childNamed("RemoteEvents")] = {
			[bp.childNamed(self.BaseName)] = {
				[bp.attribute("Loaded", true)] = func or function(context)
					local remoteFdr = context.source.instance
					return remoteFdr
				end
			}
		}
	})
end


function BaseComponent:fireAllClients(eventName, ...)
	local remote = getOrMakeRemoteEventFolder(self.instance, self.BaseName):FindFirstChild(eventName)
	if remote == nil then
		error(NO_REMOTE_ERROR:format(self.instance:GetFullName(), eventName))
	end

	remote:FireAllClients(...)
end


function BaseComponent:fireServer(eventName, ...)
	local remote = getRemoteEventFolderOrError(self.instance, self.BaseName):FindFirstChild(eventName)
	if remote == nil then
		error(NO_REMOTE_ERROR:format(self.instance:GetFullName(), eventName))
	end

	remote:FireServer(...)
end


function BaseComponent:bindRemoteEvent(eventName, handler)
	return self.maid:Add(self:connectRemoteEvent(eventName, handler))
end


function BaseComponent:connectRemoteEvent(eventName, handler)
	local maid = Maid.new()
	
	-- Wait a frame, as remote event connections can fire immediately if in queue.
	maid:Add(self:spawnNextFrame(function()
		if self.isServer then
			maid:Add(
				(getOrMakeRemoteEventFolder(self.instance, self.BaseName)
				:FindFirstChild(eventName) or error("No event named " .. eventName .. "!"))
				.OnServerEvent:Connect(handler)
			)
		else
			local schema = maid:Add(self:_getRemoteEventSchema(function()
				return false, {
					[bp.childNamed(eventName)] = function(context)
						return context.instance
					end
				}
			end))

			schema:OnMatched(function(remote)
				maid:Add(remote.OnClientEvent:Connect(handler))
			end)
		end
	end))

	return maid
end


function BaseComponent:connect(event, handler)
	return event:Connect(function(...)
		if self:isPaused() then return end
		handler(...)
	end)
end


function BaseComponent:bind(event, handler)
	local con = self:connect(event, handler)
	self.maid:GiveTask(con)
	return con
end


function BaseComponent:bindMaid(instance)
	local newMaid = Maid.new()
	self.maid[instance] = newMaid
	newMaid:GiveTask(instance.AncestryChanged:Connect(function(_, newParent)
		if newParent then return end
		self.maid[instance] = nil
	end))

	return newMaid
end


function BaseComponent:unbindMaid(instance)
	self.maid[instance] = nil
end


function BaseComponent:spawnNextFrame(handler, ...)
	if not self.isTesting then
		local args = {...}
		local argLen = #args

		local id
		id = self.maid:GiveTask(RunService.Heartbeat:Connect(function()
			self.maid[id] = nil
			handler(table.unpack(args, 1, argLen))
		end))
		
		return id
	else
		handler()
		return NOOP
	end
end


function BaseComponent:connectPostSimulation(handler)
	return RunService.Heartbeat:Connect(handler)
end


function BaseComponent:bindPostSimulation(handler)
	local con = self:connectPostSimulation(handler)
	self.maid:GiveTask(con)
	return con
end


function BaseComponent:connectPreRender(handler)
	return RunService.RenderStepped:Connect(handler)
end


function BaseComponent:bindPreRender(handler)
	local con = self:connectPreRender(handler)
	self.maid:GiveTask(con)
	return con
end


function BaseComponent:getTime()
	return self.man:GetTime()
end


function BaseComponent:setCycle(name, cycleLen)
	return self.man:SetCycle(self.instance, self.BaseName, name, cycleLen)
end


function BaseComponent:getCycle(name)
	return self.man:GetCycle(self.instance, self.BaseName, name)
end
BaseComponent.GetCycle = BaseComponent.getCycle

function getOrMakeRemoteEventFolder(instance, baseCompName)
	local remoteEvents = instance:FindFirstChild("RemoteEvents")
	if remoteEvents == nil then
		remoteEvents = Instance.new("Folder")
		remoteEvents.Name = "RemoteEvents"
		remoteEvents.Parent = instance
		
		CollectionService:AddTag(remoteEvents, "CompositeCrap")
	end

	local folder = remoteEvents:FindFirstChild(baseCompName)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = baseCompName
		folder.Parent = remoteEvents
	end

	return folder
end

function getRemoteEventFolderOrError(instance, baseCompName)
	local remotes = instance:FindFirstChild("RemoteEvents")
	if remotes then
		local folder = remotes:FindFirstChild(baseCompName)
		if folder then
			return folder
		end
	end
	return error("No remote event folder under instance: " .. instance:GetFullName())
end

return BaseComponent