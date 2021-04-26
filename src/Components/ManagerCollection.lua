local ManagerCollection = {}
ManagerCollection.__index = ManagerCollection

function ManagerCollection.new()
	local self = setmetatable({
		_managers = {};
	}, ManagerCollection)

	self.GetComponent = self:wrap("GetComponent")

	return self
end


function ManagerCollection:Add(man)
	self._managers[man] = true

	man:OnAny(function(...)
		self:Fire(...)
	end)
end


function ManagerCollection:wrap(method)
	return function(...)
		for man in next, self._managers do
			local result = man[method](man, ...)

			if result ~= nil then
				return result
			end
		end
	end
end

return ManagerCollection