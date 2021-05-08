-- Remove all component tags on clone, so client doesn't think it's static.

local PrototypesExtension = require(script.Parent.PrototypesExtension)

return function(man)
	if man.Prototypes then return end
	man.Prototypes = PrototypesExtension.new(man)
end