local BaseComponent = require(script.Parent.Parent.BaseComponent)
local Storage = require(script.Parent.Parent.Parent.Components.Storage)
local Root = BaseComponent:extend("Root", {
	EmbeddedComponents = {};
})

--[[
	Bridges the gap between Manager and the component tree.

	ALlows ComponentCollection to control it from the outside, while
	allowing subcomponents to act like this is a regular component.
]]

local function isWeak(comps)
	local comp = comps[Storage]
	if comp and comp.state:get("Weak", "Is") then
		return true
	end
	
	return false
end

function Root:Init()
	self:On("ComponentRemoved", function()
		if not next(self.added) or isWeak(self.added) then
			self:Destroy()
		end
	end)
end

-- function Root:QueueDestroyRoot()
-- 	self:QueueDestroy():andThen(function()
-- 		self:DestroyInstance(self.ref)
-- 	end)
-- end

function Root:DestroyRoot()
	self:Destroy()
	self.ref:Destroy()
end

return Root