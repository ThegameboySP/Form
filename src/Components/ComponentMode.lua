local ComponentsUtils = require(script.Parent.ComponentsUtils)

return ComponentsUtils.indexTableOrError("ComponentMode", {
	-- Overlay.
	DEFAULT = "Default";
	-- Once all components are gone, leave the instance.
	OVERLAY = "Overlay";
	-- Once all components are gone, remove the instance.
	DESTROY = "Destroy";
})