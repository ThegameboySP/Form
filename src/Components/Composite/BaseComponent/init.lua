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
local Reducers = require(script.Parent.Parent.Shared.Reducers)
local SignalMixin = require(script.Parent.SignalMixin)
local runCoroutineOrWarn = require(script.Parent.runCoroutineOrWarn)

local KeypathSubscriptions = require(script.Parent.KeypathSubscriptions)
local StateMetatable = require(script.StateMetatable)
local Utils = require(script.Utils)

local BaseComponent = SignalMixin.wrap({})
BaseComponent.BaseName = "BaseComponent"
BaseComponent.isTesting = false
BaseComponent.__index = BaseComponent

local IS_SERVER = RunService:IsServer()
local ON_SERVER_ERROR = "Can only be called on the server!"
local NO_REMOTE_ERROR = "No remote event under %s by name %s!"
local NOOP = function() end
local RET = function(...) return ... end
local DESTROYED_ERROR = function()
	error("Cannot run a component that is destroyed!")
end

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

BaseComponent.mapConfig = nil
-- When reloading, this should be run on each layer of state, then merged together.
-- When calling :start(), state is an empty table.
BaseComponent.mapState = nil

function BaseComponent.new(instance, config)
	local self = SignalMixin.new(setmetatable({
		isMirror = false;
		
		instance = instance;
		maid = Maid.new();
		externalMaid = Maid.new();
		
		config = config or {};
		state = setStateMt({});
		isDestroyed = false;

		_mirrors = {};
		_events = {};
		_layers = {};
		_layerOrder = {};
		_subscriptions = KeypathSubscriptions.new();
	}, BaseComponent))
	self._source = self

	self.maid:Add(function()
		self:Fire("Destroying")
		self:DisconnectAll()
		self.externalMaid:DoCleaning()
		
		self.PreInit = DESTROYED_ERROR
		self.Init = DESTROYED_ERROR
		self.Main = DESTROYED_ERROR

		self.isDestroyed = true
	end)

	return self
end


local function errored(_, comp)
	return comp.instance:GetFullName() .. ": Component errored:\n%s\nTraceback: %s"
end

function BaseComponent:start(instance, config)
	local comp = self.new(instance, config)

	if next(comp.config) and comp.mapConfig then
		config = comp.mapConfig(config)
	end

	local ok = runCoroutineOrWarn(errored, comp.PreInit, comp)
		and runCoroutineOrWarn(errored, comp.Init, comp)
		and runCoroutineOrWarn(errored, comp.Main, comp)

	if ok then
		return comp:newMirror(config, Symbol.named("base"))
	else
		error("Component errored, so could not continue.")
	end
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
		BaseName = Utils.getBaseComponentName(name);
	}, BaseComponent)
	newClass.__index = newClass

	function newClass.new(instance, config)
		return setmetatable(self.new(instance, config), newClass)
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
	local layerKeys = self:_getLayers()

	local config do
		local configFunc = self.mapConfig or RET
		local copyFunc = self.mapConfig and ComponentsUtils.deepCopy or RET

		local configLayers = {}
		for _, key in ipairs(layerKeys) do
			local layer = self._layers[key]
			if not next(layer.config) then continue end

			table.insert(configLayers, configFunc(copyFunc(layer.config)))
		end

		config = Reducers.merge(configLayers)
	end
	local oldConfig = self.config
	self.config = config

	if self.mapState then
		local stateLayers = {}

		for _, key in ipairs(layerKeys) do
			local layer = self._layers[key]
			if not next(layer.config) then continue end

			self._layers[key].state = setStateMt(self.mapState(
				ComponentsUtils.deepCopy(layer.config),
				self._layers[key].state
			))
			table.insert(stateLayers, key)
		end

		self:_mergeLayers(stateLayers)
	end

	self:Fire("Reloaded", ComponentsUtils.diff(config, oldConfig), oldConfig)
end


local fire = BaseComponent.Fire
function BaseComponent:Fire(name, ...)
	local methodName = "On" .. name
	if type(self[methodName]) == "function" then
		self[methodName](self, ...)
	end

	fire(self, name, ...)
end


function BaseComponent:f(method)
	return function(...)
		return method(self, ...)
	end
end


function BaseComponent:addLayer(key, state)
	return self:_newComponentLayer(key, state, nil)
end
BaseComponent.AddLayer = BaseComponent.addLayer


function BaseComponent:mergeLayer(key, delta)
	local layer = self._layers[key]

	if layer == nil then
		return self:addLayer(key, delta)
	else
		layer.state = setStateMt(Utils.deepMergeLayer(delta, layer.state))
		self:_updateState()
	end
end
BaseComponent.MergeLayer = BaseComponent.mergeLayer


function BaseComponent:removeLayer(key)
	return self:_removeComponentLayer(key)
end
BaseComponent.RemoveLayer = BaseComponent.removeLayer


local RESERVED_LAYER_KEYS = {
	[Symbol.named("remote")] = true;
	[Symbol.named("base")] = true;
}
function BaseComponent:_getLayers()
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


function BaseComponent:_mergeLayers(layerKeys)
	local newState = {}
	for _, key in ipairs(layerKeys) do
		Utils.deepMergeState(self._layers[key].state, newState)
	end
	
	for _, key in ipairs(layerKeys) do
		Utils.runStateFunctions(self._layers[key].state, newState)
	end

	local oldState = self.state
	self.state = setStateMt(newState)

	self._subscriptions:FireFromDelta(Utils.stateDiff(newState, oldState))
end


function BaseComponent:_updateState()
	return self:_mergeLayers(self:_getLayers())
end


function BaseComponent:setState(delta)
	return self:mergeLayer(Symbol.named("base"), delta)
end
BaseComponent.SetState = BaseComponent.setState


function BaseComponent:getState()
	return Utils.deepCopyState(self.state)
end
BaseComponent.GetState = BaseComponent.getState


function BaseComponent:connectSubscribe(keypath, handler)
	return self._subscriptions:Subscribe(keypath, handler)
end
BaseComponent.ConnectSubscribe = BaseComponent.connectSubscribe


function BaseComponent:subscribe(keypath, handler)
	return (self.maid:Add(self:connectSubscribe(keypath, handler)))
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
	return (self.maid:Add(self:connectSubscribeAnd(keypath, handler)))
end
BaseComponent.SubscribeAnd = BaseComponent.subscribeAnd


function BaseComponent:connectSubscribeAnd(keypath, handler)
	local disconnect = self:connectSubscribe(keypath, handler)
	local value = getStateByKeypath(self.state, keypath)
	if value ~= nil then
		handler(value)
	end
	
	return disconnect
end
BaseComponent.ConnectSubscribeAnd = BaseComponent.connectSubscribeAnd


function BaseComponent:_newComponentLayer(key, state, config)
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


function BaseComponent:_removeComponentLayer(key)
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


function BaseComponent:newMirror(config, key)
	key = self:_newComponentLayer(key, {}, config)
	self._mirrors[key] = true

	local mirror
	mirror = setmetatable({
		isMirror = true;

		DestroyMirror = function()
			if mirror.isDestroyed then return end

			mirror.isDestroyed = true
			self._mirrors[key] = nil
			if not next(self._mirrors) then
				return self:Destroy()
			end

			self:_removeComponentLayer(key)			
		end;

		GetMirrorState = function()
			return ComponentsUtils.deepCopy(self._layers[key].state)
		end;

		GetMirrorConfig = function()
			return ComponentsUtils.deepCopy(self._layers[key].config)
		end;

		Reload = function(_, newConfig)
			if newConfig then
				self._layers[key].config = newConfig
			end

			self._source:Reload()
		end;
	}, {__index = self})

	return mirror
end

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

	if not self.isTesting then
		local args = {...}
		UserUtils.callOnReplicated(self.instance, self.maid, function()
			remote:FireAllClients(table.unpack(args, 1, #args))
		end)
	else
		remote:FireAllClients(...)
	end
end


function BaseComponent:fireClient(eventName, client, ...)
	local remote = getOrMakeRemoteEventFolder(self.instance, self.BaseName):FindFirstChild(eventName)
	if remote == nil then
		error(NO_REMOTE_ERROR:format(self.instance:GetFullName(), eventName))
	end

	if not self.isTesting then
		local args = {...}
		UserUtils.callOnReplicated(self.instance, self.maid, function()
			remote:FireClient(client, table.unpack(args, 1, #args))
		end)
	else
		remote:FireClient(client, ...)
	end
end


function BaseComponent:fireServer(eventName, ...)
	local maid, id = self.maid:Add(Maid.new())
	local schema = maid:Add(self:_getRemoteEventSchema(function()
		return false, {
			[bp.childNamed(eventName)] = function(context)
				return context.instance
			end
		}
	end))

	local args = {...}
	schema:OnMatched(function(remote)
		self.maid:Remove(id)
		remote:FireServer(table.unpack(args, 1, #args))
	end)
end


function BaseComponent:bindRemoteEvent(eventName, handler)
	return self.maid:Add(self:connectRemoteEvent(eventName, handler))
end


function BaseComponent:connectRemoteEvent(eventName, handler)
	local maid = Maid.new()
	
	-- Wait a frame, as remote event connections can fire immediately if in queue.
	maid:Add(self:spawnNextFrame(function()
		if self.isServer and not self.isTesting then
			maid:Add(
				(getOrMakeRemoteEventFolder(self.instance, self.BaseName)
				:FindFirstChild(eventName) or error("No event named " .. eventName .. "!"))
				.OnServerEvent:Connect(handler)
			)
		else
			local bind = self.isServer and "OnServerEvent" or "OnClientEvent"
			local schema = maid:Add(self:_getRemoteEventSchema(function()
				return false, {
					[bp.childNamed(eventName)] = function(context)
						return context.instance
					end
				}
			end))

			schema:OnMatched(function(remote)
				maid:DoCleaning()
				maid:Add(remote[bind]:Connect(handler))
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