local BaseComponent = require(script.Parent.BaseComponent)
local Maid = require(script.Parent.Parent.Modules.Maid)

local MaidComponent = BaseComponent:extend("MaidComponent", {
	Bind = function(self, event, handler)
		return self.maid:Add(event:Connect(handler))
	end;
})

function MaidComponent.new(...)
	local self = BaseComponent.new(...)
	self.maid = Maid.new()
	return self
end

return MaidComponent