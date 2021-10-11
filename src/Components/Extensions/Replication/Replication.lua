local ServerReplicationExtension = require(script.Parent.ServerReplicationExtension)
local ClientReplicationExtension = require(script.Parent.ClientReplicationExtension)

return function(man, callbacks)
	if man.Replication then return end

	if man.IsServer then
		man.Replication = ServerReplicationExtension.new(man, callbacks)
		man.Replication:Init()
	else
		man.Replication = ClientReplicationExtension.new(man)
		man.Replication:Init()
	end
end