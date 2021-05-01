local ComponentsUtils = require(script.Parent.Parent.Parent.Shared.ComponentsUtils)

return function(ref, compName)
	if typeof(ref) ~= "Instance" then return end
	return ComponentsUtils.getConfigFromInstance(ref, compName)
end