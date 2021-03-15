local FuncUtils = {}

function FuncUtils.hasFilter(map, filter)
	for k, value in next, map do
		if filter(value, k) then
			return true
		end
	end
	
	return false
end


function FuncUtils.filterFirst(map, filter)
	for k, value in next, map do
		if filter(value, k) then
			return value
		end
	end
	
	return nil
end

return FuncUtils