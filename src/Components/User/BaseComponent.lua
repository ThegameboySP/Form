local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Maid = require(script.Parent.Parent.Modules.Maid)
local Event = require(script.Parent.Parent.Modules.Event)
local ComponentsManager = require(script.Parent.Parent.ComponentsManager)
local ComponentsUtils = require(script.Parent.Parent.ComponentsUtils)
local UserUtils = require(script.Parent.UserUtils)
local FuncUtils = require(script.Parent.FuncUtils)

local BaseComponent = {}
BaseComponent.__index = BaseComponent

local IS_SERVER = RunService:IsServer()
local ON_SERVER_ERROR = "Can only be called on the server!"
local NO_REMOTE_ERROR = "No remote event under %s by name %s!"

BaseComponent.ComponentName = "BaseComponent"
BaseComponent.NetworkMode = ComponentsManager.NetworkMode.SERVER_CLIENT
BaseComponent.util = UserUtils
BaseComponent.func = FuncUtils
BaseComponent.isServer = IS_SERVER

function BaseComponent.getInterfaces()
	return {}
end

function BaseComponent.new(instance, config)
	return setmetatable({
		instance = instance;
		maid = Maid.new();
		config = config;
		player = Players.LocalPlayer;

		_events = {};
	}, BaseComponent)
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
		_baseComponentName = ComponentsUtils.getBaseComponentName(name);
	}, {__index = self})
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
-- Unlike the others, this has its own coroutine.
function BaseComponent:Main()
	-- pass
end


function BaseComponent:setState(newState)
	self.man:SetState(self.instance, self._baseComponentName, newState)
end


function BaseComponent:subscribe(state, handler)
	return self.man:Subscribe(
		self.instance, self._baseComponentName, state, handler
	)
end


function BaseComponent:subscribeAnd(state, handler)
	local con = self.man:Subscribe(
		self.instance, self._baseComponentName, state, handler
	)
	handler(self.state[state])
	return con
end


function BaseComponent:registerEvents(events)
	for k, v in next, events do
		local event = Event.new()
		
		if type(v) == "function" then
			self._events[tostring(k)] = event
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


function BaseComponent:hasEvent(eventName)
	return self._events[eventName] ~= nil
end


function BaseComponent:fireInstanceEvent(eventName, ...)
	self.man:FireInstanceEvent(self.instance, eventName, ...)
end


function BaseComponent:connectInstanceEvent(eventName, ...)
	return self.man:ConnectInstanceEvent(self.instance, eventName, ...)
end


function BaseComponent:fireAll(eventName, ...)
	self:fireInstanceEvent(eventName, ...)
	self:fireAllClients(eventName, ...)
end


function BaseComponent:registerRemoteEvents(remotes)
	assert(IS_SERVER, ON_SERVER_ERROR)

	local folder = getOrMakeRemoteEventFolder(self.instance)
	for k, v in next, remotes do
		local remote = Instance.new("RemoteEvent")

		if type(v) == "function" then
			remote.Name = tostring(k)
			self:connectRemoteEvent(remote.Name, v)
		elseif type(v) == "string" then
			remote.Name = v
		end

		remote.Parent = folder
	end
end


function BaseComponent:_getRemoteEventFolderOrSignal()
	local folder = self.instance:FindFirstChild("RemoteEvents")
	if folder then
		return folder
	end

	local bindable = Instance.new("BindableEvent")
	local id
	local con = self.maid:GiveTask(self.instance.ChildAdded:Connect(function(child)
		if child.Name == "RemoteEvents" and child:IsA("Folder") then
			bindable:Fire()
			self.maid[id] = nil
		end
	end))

	id = self.maid:GiveTask(function()
		con:Disconnect()
		bindable:Destroy()
	end)

	return bindable.Event
end


function BaseComponent:waitForRemoteEvents()
	local result = self:_getRemoteEventFolderOrSignal()
	if result:IsA("Folder") then
		return result
	end

	return result:Wait()
end


function BaseComponent:bindOnRemoteEvents(handler)
	local result = self:_getRemoteEventFolderOrSignal()
	if result:IsA("Folder") then
		return handler(result)
	end

	-- No need to wrap in maid here, since bindable is already maided.
	result:Connect(handler)
end


function BaseComponent:areRemoteEventsLoaded()
	return self.instance:FindFirstChild("RemoteEvents") ~= nil
end


function BaseComponent:fireAllClients(eventName, ...)
	local remote = getOrMakeRemoteEventFolder(self.instance):FindFirstChild(eventName)
	if remote == nil then
		error(NO_REMOTE_ERROR:format(self.instance:GetFullName(), remote.Name))
	end

	remote:FireAllClients(...)
end


function BaseComponent:fireServer(eventName, ...)
	local remote = getRemoteEventFolderOrError(self.instance):FindFirstChild(eventName)
	if remote == nil then
		error(NO_REMOTE_ERROR:format(self.instance:GetFullName(), remote.Name))
	end

	remote:FireServer(...)
end


function BaseComponent:connectRemoteEvent(eventName, handler)
	-- Wait a frame, as remote event connections can fire immediately if in queue.
	return self:spawnNextFrame(function()
		if IS_SERVER then
			self.maid:GiveTask(
				getOrMakeRemoteEventFolder(self.instance)
				:WaitForChild(eventName)
				.OnServerEvent:Connect(handler)
			)
		else
			self.maid:GiveTask(
				getRemoteEventFolderOrError(self.instance)
				:WaitForChild(eventName)
				.OnClientEvent:Connect(handler)
			)
		end
	end)
end


function BaseComponent:addToGroup(group)
	self.man:AddToGroup(self.instance, group)
end


function BaseComponent:removeFromGroup(group)
	self.man:RemoveFromGroup(self.instance, group)
end


function BaseComponent:isPaused()
	return false
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
	return self.man:SetCycle(self.instance, self._baseComponentName, name, cycleLen)
end


function BaseComponent:getCycle(name)
	return self.man:GetCycle(self.instance, self._baseComponentName, name)
end


function BaseComponent:getConfig(instance, compName)
	assert(typeof(instance) == "Instance", "No instance!")
	return ComponentsUtils.getConfigFromInstance(instance, compName)
end

function getOrMakeRemoteEventFolder(instance)
	assert(IS_SERVER, ON_SERVER_ERROR)

	local remoteEvents = instance:FindFirstChild("RemoteEvents")
	if remoteEvents == nil then
		remoteEvents = Instance.new("Folder")
		remoteEvents.Name = "RemoteEvents"
		remoteEvents.Parent = instance
		
		CollectionService:AddTag(remoteEvents, "CompositeCrap")
	end

	return remoteEvents
end

function getRemoteEventFolderOrError(instance)
	local fullName = instance:GetFullName()
	return instance:FindFirstChild("RemoteEvents") or error("No remote event folder under instance: " .. fullName)
end

return BaseComponent