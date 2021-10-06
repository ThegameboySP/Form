local ComponentsUtils = require(script.Parent.ComponentsUtils)

return ComponentsUtils.indexTableOrError("NetworkMode", {
	Server = "Server";
	Client = "Client";
	Shared = "Shared";
})