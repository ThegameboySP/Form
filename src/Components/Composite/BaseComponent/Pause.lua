local Pause = {}
Pause.__index = Pause

function Pause.new(comp)
	return setmetatable({
		_base = comp;
		_isPaused = false;
	}, Pause)
end


function Pause:Destroy()
	-- pass
end


function Pause:Wrap(func)
	return function(...)
		if self:IsPaused() then return end
		func(...)
	end
end


function Pause:IsPaused()
	return self._isPaused
end


function Pause:Pause()
	if self._isPaused then return end
	self._isPaused = true
	self._base:Fire("Paused")
end


function Pause:Unpause()
	if not self._isPaused then return end
	self._isPaused = false
	self._base:Fire("Unpaused")
end

return Pause