local ComponentsUtils = require(script.Parent.Parent.ComponentsUtils)

return function(ref, compName)
	if typeof(ref) ~= "Instance" then return end
	return ComponentsUtils.getConfigFromInstance(ref, compName)
end