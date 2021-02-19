local ComponentsGroup = {}
ComponentsGroup.__index = ComponentsGroup

function ComponentsGroup.new()
	return setmetatable({
		_componentsHash = {};
		_componentsList = {};
	}, ComponentsGroup)
end


function ComponentsGroup:GetAdded()
	return self._componentsList
end


function ComponentsGroup:IsAdded(component)
	return self._componentsHash[component] ~= nil
end


function ComponentsGroup:Add(component)
	if self._componentsHash[component] then return end

	local index = #self._componentsList + 1
	self._componentsHash[component] = index
	self._componentsList[index] = component
end


function ComponentsGroup:Remove(component)
	if not self._componentsHash[component] then return end

	local index = self._componentsHash[component]
	self._componentsHash[component] = nil
	table.remove(self._componentsList, index)
end

return ComponentsGroup