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


function FuncUtils.filter(map, filter)
	local new = {}
	for k, value in next, map do
		if filter(value, k) then
			table.insert(new, value)
		end
	end

	return new
end


function FuncUtils.map(map, mapper)
	local new = {}
	for k, value in next, map do
		table.insert(new, mapper(value, k))
	end

	return new
end


function FuncUtils.forEach(map, func, ...)
	for k, value in next, map do
		func(value, k, ...)
	end
end

return FuncUtils