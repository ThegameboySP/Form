local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Maid = require(script.Parent.Parent.Modules.Maid)
local Symbol = require(script.Parent.Parent.Modules.Symbol)
local bp = require(script.Parent.Parent.Modules.bp)
local ComponentsUtils = require(script.Parent.Parent.Shared.ComponentsUtils)
local NetworkMode = require(script.Parent.Parent.Shared.NetworkMode)
local UserUtils = require(script.Parent.User.UserUtils)
local FuncUtils = require(script.Parent.User.FuncUtils)
local Reducers = require(script.Parent.Parent.Shared.Reducers)
local SignalMixin = require(script.Parent.SignalMixin)
local TimeCycle = require(script.Parent.TimeCycle)
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
-- This should be run on each layer of state, then merged together.
BaseComponent.mapState = nil

function BaseComponent.new(ref, config)
	local self = SignalMixin.new(setmetatable({
		isMirror = false;
		
		ref = ref;
		maid = Maid.new();
		externalMaid = Maid.new();
		
		config = config or {};
		state = setStateMt({});
		isDestroyed = false;

		_mirrors = {};
		_layers = {};
		_layerOrder = {};
		_subscriptions = KeypathSubscriptions.new();
		_cycles = {};
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
	local prefix = ""
	if typeof(comp.ref) == "Instance" then
		prefix = comp.ref:GetFullName() .. ": "
	end

	return prefix .. "Component errored:\n%s\nTraceback: %s"
end

function BaseComponent:start(ref, config)
	local comp = self.new(ref, {})
	return comp:NewMirror(config, Symbol.named("base"))
end


function BaseComponent:run(ref, config)
	local mirror = self:start(ref, config)
	local comp = mirror._source

	local ok = runCoroutineOrWarn(errored, comp.PreInit, comp)
		and runCoroutineOrWarn(errored, comp.Init, comp)
		and runCoroutineOrWarn(errored, comp.Main, comp)

	assert(ok, "Component errored, so could not continue.")
	return mirror
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
	local layerKeys = self:_getLayers()

	local config do
		local configFunc = self.mapConfig or RET
		local copyFunc = self.mapConfig and ComponentsUtils.deepCopy or RET

		local configLayers = {}
		for _, key in ipairs(layerKeys) do
			local layer = self._layers[key]
			if not next(layer.config) then continue end

			local newConfig = configFunc(copyFunc(layer.config))
			table.insert(configLayers, newConfig)
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

		self:_mergeStateLayers(stateLayers)
	end

	return oldConfig
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


function BaseComponent:AddLayer(key, state)
	return self:_newComponentLayer(key, state, nil)
end


function BaseComponent:MergeLayer(key, delta)
	local layer = self._layers[key]

	if layer == nil then
		return self:AddLayer(key, delta)
	else
		layer.state = setStateMt(Utils.deepMergeLayer(delta, layer.state))
		self:_updateState()
	end
end


function BaseComponent:RemoveLayer(key)
	return self:_removeComponentLayer(key)
end


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


function BaseComponent:_mergeStateLayers(layerKeys)
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
	return self:_mergeStateLayers(self:_getLayers())
end


function BaseComponent:SetState(delta)
	return self:MergeLayer(Symbol.named("base"), delta)
end


function BaseComponent:GetState()
	return Utils.deepCopyState(self.state)
end


function BaseComponent:ConnectSubscribe(keypath, handler)
	return self._subscriptions:Subscribe(keypath, handler)
end


function BaseComponent:Subscribe(keypath, handler)
	return (self.maid:Add(self:ConnectSubscribe(keypath, handler)))
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


function BaseComponent:NewMirror(config, key)
	key = self:_newComponentLayer(key, {}, config)
	self._mirrors[key] = true

	return setmetatable({
		isMirror = true;

		DestroyMirror = function(mirror)
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

			local oldConfig = self._source:Reload()
			self:Fire("Reloaded", ComponentsUtils.diff(self.config, oldConfig), oldConfig)
		end;
	}, {__index = self})
end


function BaseComponent:FireAll(eventName, ...)
	self:Fire(eventName, ...)
	self:FireAllClients(eventName, ...)
end


function BaseComponent:RegisterRemoteEvents(...)
	assert(typeof(self.ref) == "Instance")
	assert(self.isServer, ON_SERVER_ERROR)

	local folder = getOrMakeRemoteEventFolder(self.ref, self.BaseName)
	for k, v in next, {...} do
		local remote = Instance.new("RemoteEvent")

		if type(v) == "function" then
			remote.Name = tostring(k)
			self:BindRemoteEvent(remote.Name, v)
		elseif type(v) == "string" then
			remote.Name = v
		end

		remote.Parent = folder
	end

	folder:SetAttribute("Loaded", true)
end


function BaseComponent:_getRemoteEventSchema(func)
	return bp.new(self.ref, {
		[bp.childNamed("RemoteEvents")] = {
			[bp.childNamed(self.BaseName)] = {
				[bp.attribute("Loaded", true)] = func or function(context)
					local remoteFdr = context.source.ref
					return remoteFdr
				end
			}
		}
	})
end

function BaseComponent:FireAllClients(eventName, ...)
	assert(typeof(self.ref) == "Instance")

	local remote = getOrMakeRemoteEventFolder(self.ref, self.BaseName):FindFirstChild(eventName)
	if remote == nil then
		error(NO_REMOTE_ERROR:format(self.ref:GetFullName(), eventName))
	end

	if not self.isTesting then
		local args = {...}
		UserUtils.callOnReplicated(self.ref, self.maid, function()
			remote:FireAllClients(table.unpack(args, 1, #args))
		end)
	else
		remote:FireAllClients(...)
	end
end


function BaseComponent:FireClient(eventName, client, ...)
	assert(typeof(self.ref) == "Instance")

	local remote = getOrMakeRemoteEventFolder(self.ref, self.BaseName):FindFirstChild(eventName)
	if remote == nil then
		error(NO_REMOTE_ERROR:format(self.ref:GetFullName(), eventName))
	end

	if not self.isTesting then
		local args = {...}
		UserUtils.callOnReplicated(self.ref, self.maid, function()
			remote:FireClient(client, table.unpack(args, 1, #args))
		end)
	else
		remote:FireClient(client, ...)
	end
end


function BaseComponent:FireServer(eventName, ...)
	assert(typeof(self.ref) == "Instance")

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


function BaseComponent:BindRemoteEvent(eventName, handler)
	assert(typeof(self.ref) == "Instance")

	return self.maid:Add(self:ConnectRemoteEvent(eventName, handler))
end


function BaseComponent:ConnectRemoteEvent(eventName, handler)
	assert(typeof(self.ref) == "Instance")

	local maid = Maid.new()
	-- Wait a frame, as remote event connections can fire immediately if in queue.
	maid:Add(self:SpawnNextFrame(function()
		if self.isServer and not self.isTesting then
			maid:Add(
				(getOrMakeRemoteEventFolder(self.ref, self.BaseName)
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


function BaseComponent:Connect(event, handler)
	return event:Connect(function(...)
		if self:isPaused() then return end
		handler(...)
	end)
end


function BaseComponent:Bind(event, handler)
	local con = self:Connect(event, handler)
	self.maid:GiveTask(con)
	return con
end


function BaseComponent:SpawnNextFrame(handler, ...)
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


function BaseComponent:ConnectPostSimulation(handler)
	return RunService.Heartbeat:Connect(handler)
end


function BaseComponent:BindPostSimulation(handler)
	return self.maid:Add(self:ConnectPostSimulation(handler))
end


function BaseComponent:ConnectPreRender(handler)
	return RunService.RenderStepped:Connect(handler)
end


function BaseComponent:BindPreRender(handler)
	return self.maid:Add(self:ConnectPreRender(handler))
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