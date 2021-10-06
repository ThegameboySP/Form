local RemoteExtension = require(script.Parent.RemoteExtension)
local RemoteEmbedded = require(script.Parent.RemoteEmbedded)

return function(man)
	if man.Remote then return end

	man.Remote = RemoteExtension.new(man)
	man:RegisterEmbedded(RemoteEmbedded)
end