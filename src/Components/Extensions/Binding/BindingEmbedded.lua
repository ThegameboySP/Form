local BindingEmbedded = {}
BindingEmbedded.ClassName = "Binding"
BindingEmbedded.__index = BindingEmbedded

local EVENT_MAP = {
	Heartbeat = "PostSimulation";
	RenderStepped = "PreRender";
	Stepped = "PreSimulation";
}

function BindingEmbedded.new(base)
	local self = setmetatable({
		_base = base;
		_destructors = {};
		_extension = base.man.Binding;
		_isPaused = false;
	}, BindingEmbedded)

	base:On("Destroying", function()
		self:Destroy()
	end)

	return self
end


function BindingEmbedded:Destroy()
	for destructor in pairs(self._destructors) do
		destructor()
	end
	self._destructors = nil
end


function BindingEmbedded:Connect(binding, handler)
	handler = self:PauseWrap(handler)
	local resolvedBinding = self._base[EVENT_MAP[binding] or binding]
	
	if resolvedBinding then
		local con = resolvedBinding:Connect(handler)
		return function()
			con:Disconnect()
		end
	end

	return self._base.man.Binding:Connect(binding, handler)
end


function BindingEmbedded:Bind(binding, handler)
	local destruct = self:Connect(binding, handler)
	self._destructors[destruct] = true
	
	return function()
		self._destructors[destruct] = nil
		destruct()
	end
end


function BindingEmbedded:ToFunction(name)
	local method = self[name] or error("No method named " .. name)
	return function(...)
		return method(self, ...)
	end
end


function BindingEmbedded:Wait(seconds)
	local timestamp = tick()
	local duration = 0
	local co = coroutine.running()

	local destruct
	destruct = self:Connect("PostSimulation", function(dt)
		duration += dt
		if duration >= seconds then
			destruct()
			task.spawn(co, tick() - timestamp)
		end
	end)

	return coroutine.yield()
end


function BindingEmbedded:Delay(seconds, handler)
	local duration = 0

	local destruct
	destruct = self:Connect("PostSimulation", function(dt)
		duration += dt
		if duration >= seconds then
			destruct()
			handler()
		end
	end)
end


function BindingEmbedded:PauseWrap(handler)
	return function(...)
		if self._isPaused then return end
		handler(...)
	end
end


function BindingEmbedded:IsPaused()
	return self._isPaused
end


function BindingEmbedded:Pause()
	if self._isPaused then return end
	self._isPaused = true
	self._base:Fire("Paused")
end


function BindingEmbedded:Unpause()
	if not self._isPaused then return end
	self._isPaused = false
	self._base:Fire("Unpaused")
end


function BindingEmbedded:GetTime()
	local timeFunction = self._base.TimeFunction
	return
		timeFunction and timeFunction()
		or self._extension:GetTime()
end

return BindingEmbedded