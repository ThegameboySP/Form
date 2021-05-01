local IS_SERVER = game:GetService("RunService"):IsServer()

return {
	use = require(IS_SERVER and script.serverReplicator or script.clientReplicator);
}