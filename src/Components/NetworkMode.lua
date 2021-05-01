local ComponentsUtils = require(script.Parent.ComponentsUtils)

return ComponentsUtils.indexTableOrError("NetworkMode", {
	Server = "Server";
	Client = "Client";
	ServerClient = "ServerClient";
	Shared = "Shared";
})