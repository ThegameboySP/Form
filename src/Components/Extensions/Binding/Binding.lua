local BindingExtension = require(script.Parent.BindingExtension)
local BindingEmbedded = require(script.Parent.BindingEmbedded)

return function(man)
	if man.Binding then return end
	
	man.Binding = BindingExtension.new(man)
	man:RegisterEmbedded(BindingEmbedded)
end