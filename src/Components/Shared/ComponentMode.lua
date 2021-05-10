local ComponentsUtils = require(script.Parent.ComponentsUtils)

return ComponentsUtils.indexTableOrError("ComponentMode", {
	-- Overlay.
	Default = "Default";
	-- Once all components are gone, leave the instance.
	Overlay = "Overlay";
	-- Once all components are gone, remove the instance.
	Destroy = "Destroy";
})