local ExtensionPrototype = {}
ExtensionPrototype.__index = ExtensionPrototype

function ExtensionPrototype.new(man)
	local self = setmetatable({pending = {}}, ExtensionPrototype)
	
	man.Binding.Defer:ConnectAtPriority(10, function()
		local pending = self.pending
		if next(pending) then
			self.pending = {}

			for data in pairs(pending) do
				data:onUpdate()
			end
		end
	end)

	return self
end

return ExtensionPrototype