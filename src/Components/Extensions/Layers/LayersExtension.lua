local ExtensionPrototype = {}
ExtensionPrototype.__index = ExtensionPrototype

function ExtensionPrototype.new(man)
	local self = setmetatable({pending = {}}, ExtensionPrototype)
	
	man.Binding.Defer:ConnectAtPriority(10, function()
		local pending = self.pending
		if next(pending) then
			debug.profilebegin("Form_LayersUpdate")

			self.pending = {}

			for data in pairs(pending) do
				data:onUpdate()
			end

			debug.profileend()
		end
	end)

	return self
end

return ExtensionPrototype