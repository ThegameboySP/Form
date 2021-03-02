local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Maid = require(script.Parent.Parent.Modules.Maid)
local Event = require(script.Parent.Parent.Modules.Event)
local ComponentsManager = require(script.Parent.Parent.ComponentsManager)
local ComponentsUtils = require(script.Parent.Parent.ComponentsUtils)
local UserUtils = require(script.Parent.UserUtils)

local BaseComponent = {}
BaseComponent.NetworkMode = ComponentsManager.NetworkMode.SERVER_CLIENT
BaseComponent.ComponentName = "BaseComponent"
BaseComponent.__index = BaseComponent
BaseComponent.util = UserUtils

local IS_SERVER = RunService:IsServer()

function BaseComponent.getInterfaces()
	return {}
end

function BaseComponent.new(instance, config)
	local remoteEvents = instance:FindFirstChild("RemoteEvents")
	if remoteEvents == nil then
		remoteEvents = Instance.new("Folder")
		remoteEvents.Name = "RemoteEvents"
		remoteEvents.Parent = instance
	end

	return setmetatable({
		instance = instance;
		maid = Maid.new();
		config = config;
		player = Players.LocalPlayer;

		_remoteEvents = remoteEvents;
		_events = {};
	}, BaseComponent)
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
	self.man:SetState(self.instance, ComponentsUtils.getBaseComponentName(self.ComponentName), newState)
end


function BaseComponent:subscribe(state, handler)
	return self.man:Subscribe(
		self.instance, ComponentsUtils.getBaseComponentName(self.ComponentName), state, handler
	)
end


function BaseComponent:subscribeAnd(state, handler)
	local con = self.man:Subscribe(
		self.instance, ComponentsUtils.getBaseComponentName(self.ComponentName), state, handler
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
	for k, v in next, remotes do
		local remote = Instance.new("RemoteEvent")

		if type(v) == "function" then
			remote.Name = tostring(k)
			self:connectRemoteEvent(remote.Name, v)
		elseif type(v) == "string" then
			remote.Name = v
		end

		remote.Parent = self._remoteEvents
	end
end


function BaseComponent:fireAllClients(eventName, ...)
	local remote = self._remoteEvents:FindFirstChild(eventName)
	if remote == nil then
		error(("No remote event under %s by name %s!"):format(self.instance:GetFullName(), remote.Name))
	end

	remote:FireAllClients(...)
end


function BaseComponent:fireServer(eventName, ...)
	local remote = self._remoteEvents:FindFirstChild(eventName)
	if remote == nil then
		error(("No remote event under %s by name %s!"):format(self.instance:GetFullName(), remote.Name))
	end

	remote:FireServer(...)
end


function BaseComponent:connectRemoteEvent(eventName, handler)
	return self:spawnNextFrame(function()
		if IS_SERVER then
			self.maid:GiveTask(self._remoteEvents:WaitForChild(eventName).OnServerEvent:Connect(handler))
		else
			self.maid:GiveTask(self._remoteEvents:WaitForChild(eventName).OnClientEvent:Connect(handler))
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


function BaseComponent:spawnNextFrame(handler)
	local id
	id = self.maid:GiveTask(RunService.Heartbeat:Connect(function()
		self.maid[id] = nil
		handler()
	end))
	
	return id
end


function BaseComponent:getConfig(instance, compName)
	assert(instance, "No instance!")
	return ComponentsUtils.getConfigFromInstance(instance, compName)
end

return BaseComponent