local Maid = require(script.Parent.Parent.Modules.Maid)
local ComponentsManager = require(script.Parent.Parent.ComponentsManager)

local BaseComponent = {}
BaseComponent.NetworkMode = ComponentsManager.NetworkMode.SERVER_CLIENT
BaseComponent.ComponentName = "BaseComponent"
BaseComponent.__index = BaseComponent

function BaseComponent.getInterfaces()
	return {}
end

function BaseComponent.new(instance, props)
	return setmetatable({
		instance = instance;
		maid = Maid.new();
		props = props;
	}, BaseComponent)
end


function BaseComponent:Destroy()
	self.maid:DoCleaning()
end


function BaseComponent:Main()
	-- pass
end


function BaseComponent:setState(newState)
	self.manager:SetState(self.instance, self.ComponentName, newState)
end


function BaseComponent:subscribe(state, handler)
	return self.manager:Subscribe(self.instance, self.ComponentName, state, handler)
end


function BaseComponent:subscribeAnd(state, handler)
	local con = self.manager:Subscribe(self.instance, self.ComponentName, state, handler)
	handler(self.state[state])
	return con
end


function BaseComponent:AddToGroup(group)
	self.manager:AddToGroup(self.instance, group)
end


function BaseComponent:RemoveFromGroup(group)
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