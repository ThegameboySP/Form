local ExtensionPrototype = {}
ExtensionPrototype.__index = ExtensionPrototype

function ExtensionPrototype.new(man)
	if man.Data then return end
	
	local self = setmetatable({}, ExtensionPrototype)
	man.Data = self

	man.Binding.Defer:ConnectAtPriority(10, function()
		for data in pairs(self) do
			data:onUpdate()
		end

		table.clear(self)
	end)

	return self
end

return ExtensionPrototype