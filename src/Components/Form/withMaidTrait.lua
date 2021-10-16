local Maid = require(script.Parent.Parent.Modules.Maid)

return function(class)
	local newClass = {}
	for k, v in pairs(class) do
		newClass[k] = v
	end
	newClass.__index = newClass

	local new = class.new
	function newClass.new(...)
		local self = setmetatable(new(...), newClass)
		self.maid = Maid.new()
		return self
	end

	local destroy = class.Destroy
	function newClass:Destroy(...)
		self.maid:DoCleaning()
		destroy(self, ...)
	end

	function newClass:Bind(p1, p2)
		if type(p1) == "table" then
			for event, handler in pairs(p1) do
				self.maid:Add(event:Connect(handler))
			end
		end

		return self.maid:Add(p1:Connect(p2))
	end

	return newClass
end