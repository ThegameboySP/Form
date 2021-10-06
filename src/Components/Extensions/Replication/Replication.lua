local ReplicationExtension = require(script.Parent.ReplicationExtension)

return function(man)
	if man.Replication then return end

	man.Replication = ReplicationExtension.new(man)
	if man.IsServer then
		man.Replication:InitServer()
	else
		man.Replication:InitClient()
	end
end