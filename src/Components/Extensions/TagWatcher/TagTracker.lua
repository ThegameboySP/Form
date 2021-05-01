-- Exposes events for when any instance is given a tag that matches a currently registered component. Reusable.

local TagTracker = {}
TagTracker.__index = TagTracker

function TagTracker.new(man)
	local self = setmetatable({_man = man}, TagTracker)
	man:On("ClassRegistered", function(class)

	end)

	return self
end

return TagTracker