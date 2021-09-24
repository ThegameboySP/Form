local ComponentsUtils = require(script.Parent.ComponentsUtils)

local Reducers = {}

function Reducers.merge(values)
	local final = {}
	for _, value in ipairs(values) do
		final = ComponentsUtils.copylessDeepMerge(value, final)
	end

	return final
end

function Reducers.hook(array)
	local type = type(array[1])

	if type == "table" then
		local final = {}
		for _, value in ipairs(array) do
			final = ComponentsUtils.shallowMerge(value, final)
		end

		return final
	elseif type == "nil" then
		return nil
	else
		return array[#array]
	end
end

return Reducers