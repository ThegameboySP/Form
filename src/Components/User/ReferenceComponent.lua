local RunService = game:GetService("RunService")

local BaseComponent = require(script.Parent.BaseComponent)
local Maid = require(script.Parent.Parent.Modules.Maid)

local ReferenceComponent = setmetatable({}, {__index = BaseComponent})
ReferenceComponent.ComponentName = "ReferenceComponent"
ReferenceComponent.__index = ReferenceComponent

local function resolvePath(str)
	local instance

	for name in str:gmatch("([^.]).?") do
		instance = instance and instance:FindFirstChild(name) or game[name]

		if instance == nil then
			return nil
		end
	end

	local wrapper = Instance.new("ObjectValue")
	wrapper.Value = instance
	return wrapper
end


function ReferenceComponent.initInstance(instance, man)
	if not instance:IsA("ObjectValue") or not instance.Value then
		return false
	end
	
	if not man.filters.isAddable(instance.Value) then
		return false
	end

	local newValue = Instance.new("StringValue")
	newValue.Name = "Path"
	newValue.Value = instance.Value:GetFullName()
	newValue.Parent = instance
end


function ReferenceComponent.new(instance, config)
	return setmetatable(BaseComponent.new(instance, config), ReferenceComponent)
end


function ReferenceComponent:Init()
	self._path = self.instance.Path.Value
	self:_tryNewInstance()

	self:bind(RunService.Heartbeat, function()
		if self._tracking.Value == nil then
			self:_tryNewInstance()
		end
	end)
end


function ReferenceComponent:_tryNewInstance()
	self._tracking = resolvePath(self._path)

	if self._tracking then
		if self.man:GetCloneProfile(self._tracking.Value) then
			self:_bindComponentPath(self._tracking.Value)
		else
			self:_bindNonComponentPath(self._tracking.Value)
		end
	else
		warn(("Lost instance: %s"):format(self._path))
		self:Destroy()
	end
end


function ReferenceComponent:_bindNonComponentPath(instance)
	local bindMaid = Maid.new()
	self.maid.bindMaid = bindMaid

	local currentInstance = instance
	while currentInstance.Parent ~= game do
		bindMaid:GiveTask(currentInstance.AncestryChanged:Connect(function(_, newParent)
			if newParent then return end

			-- Assumes the next instance is going to come after some arbitrary yield.
			self:spawnNextFrame(function()

				if self.man:GetCloneProfile(self._tracking) then
					self:_bindComponentPath(
			end)
		end))

		bindMaid:GiveTask(self.man.ComponentAdded:Connect(function(instance)
			if instance ~= currentInstance then return end

			
		end))

		currentInstance = currentInstance.Parent
	end
end


function ReferenceComponent:_bindComponentPath(instance)
	local bindMaid = Maid.new()
	self.maid.bindMaid = bindMaid

	local currentInstance = instance
	while currentInstance.Parent ~= game do
		bindMaid:GiveTask(currentInstance.AncestryChanged:Connect(function(_, newParent)
			if newParent then return end

			-- Assumes the next instance is going to come after some arbitrary yield.
			self:spawnNextFrame(function()
				if not self.man:GetCloneProfile(instance) then
					self._tracking = resolvePath(self._path)
					self:_bindComponentPath(self._tracking)
				end
			end)
		end))

		currentInstance = currentInstance.Parent
	end
end

return ReferenceComponent