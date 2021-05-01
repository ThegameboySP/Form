local NetworkMode = require(script.Parent.Parent.NetworkMode)
local BaseComponent = require(script.Parent.BaseComponent)

local ReferenceComponent = BaseComponent:extend("ReferenceComponent")
ReferenceComponent.NetworkMode = NetworkMode.Shared

--[[
	Tries to keep an up-to-date value on the current clone of what it's pointing to.	
	Never use this on both server and client.

	If using on client, make sure what it's pointing to is also client-only, otherwise
	it can be nil once the player joins and break the component.
]]

local function resolvePath(str)
	local instance

	for name in str:gmatch("([^.]).?") do
		instance = instance and instance:FindFirstChild(name) or game[name]

		if instance == nil then
			return nil
		end
	end

	return instance
end


function ReferenceComponent.initInstance(instance)
	if not instance:IsA("ObjectValue") or not instance.Value then
		return false
	end

	if instance:FindFirstChild("Path") then
		return
	end
	
	local newValue = Instance.new("StringValue")
	newValue.Name = "Path"
	newValue.Value = instance.Value:GetFullName()
	newValue.Parent = instance
end


function ReferenceComponent.new(instance, config)
	return setmetatable(BaseComponent.new(instance, config), ReferenceComponent)
end


function ReferenceComponent:PreInit()
	self._path = self.instance.Path.Value

	local clone = self:_tryResolveOrReturn()
	self._clone = clone
	self.instance.Value = clone
end


function ReferenceComponent:TryResolve()
	if self._clone then
		return self._clone
	end

	return self:_tryResolve()
end


function ReferenceComponent:_tryResolve()
	local profile

	if self.instance.Value then
		profile = self.man:GetCloneProfileFromPrototype(self.instance.Value)
			or self.man:GetCloneProfile(self.instance.Value)
	elseif not self.instance.Value then
		local resolved = resolvePath(self._path)
		if resolved == nil then
			return nil
		end

		profile = self.man:GetCloneProfileFromPrototype(resolved) or self.man:GetCloneProfile(resolved)
	end

	return profile and profile.clone or nil
end


function ReferenceComponent:_tryResolveOrReturn()
	local clone = self:_tryResolve()
	if clone == nil then
		warn(("Couldn't find instance at path: %s"):format(self._path))
		return
	end
	
	return clone
end

return ReferenceComponent