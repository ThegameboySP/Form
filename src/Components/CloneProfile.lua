local Event = require(script.Parent.Modules.Event)

local CloneProfile = {}
CloneProfile.__index = CloneProfile

function CloneProfile.new(clone, prototype, synced)
	return setmetatable({
		ComponentAdded = Event.new();
		ComponentRemoved = Event.new();

		clone = clone;
		prototype = prototype;
		synced = synced;
		unsafeConfigMap = {};

		_components = {};
		_groups = {};
		_destructFuncs = {};
	}, CloneProfile)
end


function CloneProfile:GetComponentsHash()
	return self._components
end


function CloneProfile:AddComponent(componentName)
	self._components[componentName] = true
	self.ComponentAdded:Fire(componentName)
end


function CloneProfile:RemoveComponent(componentName)
	self._components[componentName] = nil
	self.ComponentRemoved:Fire(componentName)
end


function CloneProfile:HasComponent(componentName)
	return self._components[componentName] == true
end


function CloneProfile:HasAComponent()
	return next(self._components) ~= nil
end


function CloneProfile:GetGroupsHash()
	return self._groups
end


function CloneProfile:AddGroup(group)
	self._groups[group] = true
end


function CloneProfile:RemoveGroup(group)
	self._groups[group] = nil
end


function CloneProfile:IsInGroup(group)
	return self._groups[group] ~= nil
end


function CloneProfile:IsInAGroup()
	return next(self._groups) ~= nil
end


function CloneProfile:AddDestructFunction(func)
	table.insert(self._destructFuncs, func)
end


function CloneProfile:Destruct()
	for index, func in next, self._destructFuncs do
		self._destructFuncs[index] = nil
		func()
	end

	self.ComponentAdded:Destroy()
	self.ComponentRemoved:Destroy()
end


function CloneProfile:GetDestructFunctionsArray()
	return self._destructFuncs
end

return CloneProfile