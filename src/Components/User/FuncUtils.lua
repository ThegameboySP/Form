local FuncUtils = {}

function FuncUtils.hasFilter(map, filter)
	for k, value in next, map do
		if filter(value, k) then
			return true
		end
	end
	
	return false
end

return FuncUtils