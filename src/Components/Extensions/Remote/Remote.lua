local RemoteExtension = require(script.Parent.RemoteExtension)
local RemoteEmbedded = require(script.Parent.RemoteEmbedded)

return function(man, overrides)
	if man.Remote then return end

	man.Remote = RemoteExtension.new(man, overrides)
	man.Remote:Init()
	man:RegisterEmbedded(RemoteEmbedded)
end