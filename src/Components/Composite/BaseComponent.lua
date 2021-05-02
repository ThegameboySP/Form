local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Maid = require(script.Parent.Parent.Modules.Maid)
local Event = require(script.Parent.Parent.Modules.Event)
local Symbol = require(script.Parent.Parent.Modules.Symbol)
local ComponentsUtils = require(script.Parent.Parent.Shared.ComponentsUtils)
local NetworkMode = require(script.Parent.Parent.Shared.NetworkMode)
local UserUtils = require(script.Parent.User.UserUtils)
local FuncUtils = require(script.Parent.User.FuncUtils)

local KeypathSubscriptions = require(script.Parent.KeypathSubscriptions)

local BaseComponent = {}
BaseComponent.__index = BaseComponent

local IS_SERVER = RunService:IsServer()
local ON_SERVER_ERROR = "Can only be called on the server!"
local NO_REMOTE_ERROR = "No remote event under %s by name %s!"

BaseComponent.ComponentName = "BaseComponent"
BaseComponent.NetworkMode = NetworkMode.ServerClient
BaseComponent.Maid = Maid
BaseComponent.util = UserUtils
BaseComponent.func = FuncUtils
BaseComponent.isServer = IS_SERVER
BaseComponent.player = Players.LocalPlayer
BaseComponent.null = Symbol.named("null")

function BaseComponent.getInterfaces()
	return {}
end

function BaseComponent.new(instance, config)
	local self = setmetatable({
		instance = instance;
		maid = Maid.new();
		config = config;

		state = {};

		_events = {};
		_layers = {};
		_layerOrder = {};
		_subscriptions = KeypathSubscriptions.new();
	}, BaseComponent)

	self:registerEvents({"Destroying"})

	return self
end


function BaseComponent.start(instance, config)
	local self = BaseComponent.new(instance, config)

	self:PreInit()
	self:Init()
	self:Start()

	return self
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


function BaseComponent:f(method)
	return function(...)
		return method(self, ...)
	end
end


function BaseComponent:addLayer(key, state, suppressCopy)
	if self._layers[key] == nil then
		table.insert(self._layerOrder, key)
	end

	if not suppressCopy then
		self._layers[key] = ComponentsUtils.deepCopy(state)
	else
		self._layers[key] = state
	end

	self:_updateState()
end
BaseComponent.AddLayer = BaseComponent.addLayer


function BaseComponent:mergeLayer(key, delta)
	local layer = self._layers[key]
	if layer == nil then
		self:addLayer(key, delta, false)
	else
		self._layers[key] = ComponentsUtils.deepMerge(delta, layer)
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
	local newState = {}

	local layersToMerge = {self._layers[Symbol.named("remote")]}
	table.insert(layersToMerge, self._layers[Symbol.named("base")])

	for _, layerKey in ipairs(self._layerOrder) do
		if RESERVED_LAYER_KEYS[layerKey] then continue end
		table.insert(layersToMerge, self._layers[layerKey])
	end

	for _, layer in ipairs(layersToMerge) do
		newState = ComponentsUtils.deepMerge(layer, newState)
	end

	local oldState = self.state
	self.state = newState

	self._subscriptions:FireFromDelta(ComponentsUtils.diff(newState, oldState))
end


function BaseComponent:setState(delta)
	return self:mergeLayer(Symbol.named("base"), delta)
end
BaseComponent.SetState = BaseComponent.setState


function BaseComponent:getState()
	return ComponentsUtils.deepCopy(self.state)
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

function BaseComponent:registerEvents(events)
	for k, v in next, events do
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


function BaseComponent:registerRemoteEvents(remotes)
	assert(IS_SERVER, ON_SERVER_ERROR)

	local folder = getOrMakeRemoteEventFolder(self.instance, self.BaseName)
	for k, v in next, remotes do
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


function BaseComponent:_getRemoteEventFolderOrSignal()
	local subMaid = Maid.new()
	local bindable = Instance.new("BindableEvent")
	subMaid:GiveTask(bindable)
	local id = self.maid:GiveTask(subMaid)

	local function onInstanceChildAdded(child)
		if child.Name ~= "RemoteEvents" or not child:IsA("Folder") then return end

		local function onRemoteFolderAdded(remoteFdr)
			if remoteFdr.Name ~= self.BaseName then return end

			local function onLoaded()
				self.maid[id] = nil
				bindable:Fire(remoteFdr)
				return remoteFdr
			end
			
			subMaid:GiveTask(remoteFdr:GetAttributeChangedSignal("Loaded"):Connect(onLoaded))
			if remoteFdr:GetAttribute("Loaded") then
				return onLoaded()
			end
		end

		subMaid:GiveTask(child.ChildAdded:Connect(onRemoteFolderAdded))

		local remoteFdr = child:FindFirstChild(self.BaseName)
		if remoteFdr then
			return onRemoteFolderAdded(remoteFdr)
		end
	end

	local folder = self.instance:FindFirstChild("RemoteEvents")
	if folder then
		local remoteFdr = onInstanceChildAdded(folder)
		if remoteFdr then
			return remoteFdr
		end
	end

	subMaid:GiveTask(self.instance.ChildAdded:Connect(onInstanceChildAdded))
	return bindable.Event
end


function BaseComponent:waitForRemoteEvents()
	local result = self:_getRemoteEventFolderOrSignal()
	if typeof(result) ~= "RBXScriptSignal" then
		return result
	end

	return result:Wait()
end
BaseComponent.WaitForRemoteEvents = BaseComponent.waitForRemoteEvents


function BaseComponent:bindOnRemoteEvents(handler)
	local result = self:_getRemoteEventFolderOrSignal()
	if typeof(result) ~= "RBXScriptSignal" then
		return handler(result)
	end

	-- No need to wrap in maid here, since bindable is already maided.
	result:Connect(handler)
end


function BaseComponent:areRemoteEventsLoaded()
	return self.instance:FindFirstChild("RemoteEvents") ~= nil
end
BaseComponent.AreRemoteEventsLoaded = BaseComponent.areRemoteEventsLoaded


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
	local id = self:spawnNextFrame(function()
		maid.id = nil

		if IS_SERVER then
			maid:Add(
				(getOrMakeRemoteEventFolder(self.instance, self.BaseName)
				:FindFirstChild(eventName) or error("No event named " .. eventName .. "!"))
				.OnServerEvent:Connect(handler)
			)
		else
			local folder = getRemoteEventFolderOrError(self.instance, self.BaseName)
			local event = folder:FindFirstChild(eventName)
			if event == nil then
				maid.childAdded = folder.ChildAdded:Connect(function(child)
					if child.Name ~= eventName then return end
					maid.childAdded = nil
					maid:Add(child.OnClientEvent:Connect(handler))
				end)
			else
				maid:Add(event.OnClientEvent:Connect(handler))
			end
		end
	end)

	maid.id = function()
		self.maid[id] = nil
	end

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


function BaseComponent:spawnNextFrame(handler)
	local id
	id = self.maid:GiveTask(RunService.Heartbeat:Connect(function()
		self.maid[id] = nil
		handler()
	end))
	
	return id
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


function BaseComponent:getConfig(instance, compName)
	assert(typeof(instance) == "Instance", "No instance!")
	return ComponentsUtils.getConfigFromInstance(instance, compName)
end
BaseComponent.GetConfig = BaseComponent.getConfig

function getOrMakeRemoteEventFolder(instance, baseCompName)
	assert(IS_SERVER, ON_SERVER_ERROR)

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