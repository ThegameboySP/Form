local IS_SERVER = game:GetService("RunService"):IsServer()

return function(man)
	if man.Replicator then return end
	
	if IS_SERVER then
		man.Replicator = require(script.Parent.serverReplicator)(man)
	else
		man.Replicator = require(script.Parent.clientReplicator)(man)
	end
end