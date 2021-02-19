local CloneProfile = {}
CloneProfile.__index = CloneProfile

function CloneProfile.new(clone, prototype, synced)
	return setmetatable({
		clone = clone;
		prototype = prototype;
		synced = synced;

		_components = {};
		_groups = {};
	}, CloneProfile)
end


function CloneProfile:GetComponentsHash()
	return self._components
end


function CloneProfile:AddComponent(componentName)
	self._components[componentName] = true
end


function CloneProfile:RemoveComponent(componentName)
	self._components[componentName] = nil
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

return CloneProfile