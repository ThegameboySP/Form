local inlinedError = require(script.Parent.Parent.Parent.Shared.inlinedError)

local ExtensionPrototype = {}
ExtensionPrototype.__index = ExtensionPrototype

function ExtensionPrototype.new(man)
	local self = setmetatable({}, ExtensionPrototype)
	
	man.Binding.Defer:ConnectAtPriority(10, function()
		local data = next(self)

		local i = 0
		while data and i < 1000 do
			i += 1
			self[data] = nil
			data:onUpdate()
			data = next(self)
		end

		if i >= 1000 then
			inlinedError("Reached subscriber update limit. This probably means you have a circular update loop in your code!")
		end
	end)

	return self
end

return ExtensionPrototype