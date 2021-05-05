local ComponentsUtils = require(script.Parent.ComponentsUtils)

local Reducers = {}

function Reducers.merge(values)
	local final = {}
	for _, value in ipairs(values) do
		final = ComponentsUtils.deepMerge(value, final)
	end

	return final
end

return Reducers