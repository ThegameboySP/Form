local ServerReplicationExtension = require(script.Parent.ServerReplicationExtension)
local ClientReplicationExtension = require(script.Parent.ClientReplicationExtension)

return function(man, callbacks, overrides)
	if man.Replication then return end

	if man.IsServer then
		man.Replication = ServerReplicationExtension.new(man, overrides)
		man.Replication:Init(callbacks)
	else
		man.Replication = ClientReplicationExtension.new(man, overrides)
		man.Replication:Init()
	end
end