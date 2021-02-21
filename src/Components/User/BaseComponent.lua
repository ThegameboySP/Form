local RunService = game:GetService("RunService")

local Maid = require(script.Parent.Parent.Modules.Maid)
local ComponentsManager = require(script.Parent.Parent.ComponentsManager)
local ComponentsUtils = require(script.Parent.Parent.ComponentsUtils)

local BaseComponent = {}
BaseComponent.NetworkMode = ComponentsManager.NetworkMode.SERVER_CLIENT
BaseComponent.ComponentName = "BaseComponent"
BaseComponent.__index = BaseComponent

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

		_remoteEvents = remoteEvents;
	}, BaseComponent)
end


function BaseComponent:Destroy()
	self.maid:DoCleaning()
end


function BaseComponent:Main()
	-- pass
end


function BaseComponent:setState(newState)
	self.manager:SetState(self.instance, ComponentsUtils.getBaseComponentName(self.ComponentName), newState)
end


function BaseComponent:subscribe(state, handler)
	return self.manager:Subscribe(
		self.instance, ComponentsUtils.getBaseComponentName(self.ComponentName), state, handler
	)
end


function BaseComponent:subscribeAnd(state, handler)
	local con = self.manager:Subscribe(
		self.instance, ComponentsUtils.getBaseComponentName(self.ComponentName), state, handler
	)
	handler(self.state[state])
	return con
end


function BaseComponent:registerRemoteEvents(remotes)
	for _, name in next, remotes do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
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


function BaseComponent:connectRemoteEvent(eventName, handler)
	local id
	id = self.maid:GiveTask(RunService.Heartbeat:Connect(function()
		self.maid[id] = nil
		
		if IS_SERVER then
			self.maid:GiveTask(self._remoteEvents:WaitForChild(eventName).OnServerEvent:Connect(handler))
		else
			self.maid:GiveTask(self._remoteEvents:WaitForChild(eventName).OnClientEvent:Connect(handler))
		end
	end))

	return id
end


function BaseComponent:addToGroup(group)
	self.manager:AddToGroup(self.instance, group)
end


function BaseComponent:removeFromGroup(group)
	self.manager:RemoveFromGroup(self.instance, group)
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

return BaseComponent