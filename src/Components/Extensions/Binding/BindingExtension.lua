local RunService = game:GetService("RunService")

local Callbacks = require(script.Parent.Callbacks)

local Binding = {}
Binding.ClassName = "BindingExtension"
Binding.__index = Binding

local EVENT_MAP = {
	Heartbeat = "PostSimulation";
	RenderStepped = "PreRender";
	Stepped = "PreSimulation";
}

local function extractValue(value)
	if type(value) == "table" then
		return value:Get()
	end

	return value
end

function Binding.new(man)
	local self = setmetatable({
		_ref = man;
		_cons = {};
		_isPaused = false;

		TimeFunction = os.clock;

		PreRender = Callbacks.new();
		PostSimulation = Callbacks.new();
		PreSimulation = Callbacks.new();
		Defer = Callbacks.new();
	}, Binding)

	self:Init()

	return self
end

function Binding:DisconnectFromRunService()
	for _, con in pairs(self._cons) do
		con:Disconnect()
	end
end

function Binding:Init()
	if not self._ref.IsTesting then
		table.insert(self._cons, RunService.Heartbeat:Connect(function(...)
			self.PostSimulation:Fire(...)
			task.defer(self.Defer.Fire, self.Defer)
		end))

		if not RunService:IsServer() then
			table.insert(self._cons, RunService.RenderStepped:Connect(function(...)
				self.PreRender:Fire(...)
			end))
		end

		table.insert(self._cons, RunService.Stepped:Connect(function(...)
			self.PreSimulation:Fire(...)
		end))
	end
end

function Binding:_connectAtPriority(binding, priority, handler)
	local con = self[EVENT_MAP[binding] or binding]:ConnectAtPriority(priority, handler)
	return function()
		con:Disconnect()
	end
end

function Binding:Connect(binding, handler)
	return self:_connectAtPriority(binding, 0, handler)
end

function Binding:ToFunction(name)
	local method = self[name] or error("No method named " .. name)
	return function(...)
		return method(self, ...)
	end
end

function Binding:Wait(seconds)
	local timestamp = self:GetTime()
	local co = coroutine.running()

	local disconnect
	local con
	disconnect = self:_connectAtPriority("Defer", 5, function()
		local delta = self:GetTime() - timestamp
		if delta >= extractValue(seconds) then
			disconnect()
			con:Disconnect()
			task.spawn(co, delta)
		end
	end)

	con = self._ref:On("Destroying", disconnect)

	return coroutine.yield()
end

function Binding:Delay(seconds, handler)
	local timestamp = self:GetTime()

	local disconnect
	local con
	con = self:_connectAtPriority("Defer", 5, function()
		local delta = self:GetTime() - timestamp
		if delta >= extractValue(seconds) then
			disconnect()
			con:Disconnect()
			handler(delta)
		end
	end)

	con = self._ref:On("Destroying", disconnect)
end

function Binding:PauseWrap(handler)
	return function(...)
		if self._isPaused then return end
		handler(...)
	end
end

function Binding:IsPaused()
	return self._isPaused
end

function Binding:Pause()
	if self._isPaused then return end
	self._isPaused = true
	self._ref:Fire("Paused")
end

function Binding:Unpause()
	if not self._isPaused then return end
	self._isPaused = false
	self._ref:Fire("Unpaused")
end

function Binding:GetTime()
	return self.TimeFunction()
end

return Binding