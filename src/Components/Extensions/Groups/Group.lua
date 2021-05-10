local Group = {}
Group.__index = Group

function Group.new()
	return setmetatable({
		_set = {};
		_array = {};
	}, Group)
end


function Group:GetAdded()
	return self._array
end


function Group:IsAdded(item)
	return self._set[item] ~= nil
end


function Group:Add(item)
	if self._set[item] then return end

	self._set[item] = true
	table.insert(self._array, item)
end


function Group:Remove(item)
	if not self._set[item] then return end

	self._set[item] = nil
	table.remove(self._array, table.find(self._array, item))
end

return Group