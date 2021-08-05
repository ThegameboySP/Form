local StateMetatable = {}
StateMetatable.__index = StateMetatable

function StateMetatable:get(...)
	local current = self
	for _, key in ipairs({...}) do
		current = current[key]

		if current == nil then
			return nil
		end
	end

	return current
end


function StateMetatable:getByKeyPath(keyPath)
	local current = self
	for key in keyPath:gmatch("([^.]+)%.?") do
		current = current[key]

		if current == nil then
			return nil
		end
	end

	return current
end

return StateMetatable