local RunService = game:GetService("RunService")

local Callbacks = require(script.Parent.Callbacks)

local BindingExtension = {}
BindingExtension.ClassName = "BindingExtension"
BindingExtension.__index = BindingExtension

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

local function isDestroyed(value)
	if type(value) == "table" then
		return value:IsDestroyed()
	end

	return false
end

function BindingExtension.new(man)
	local self = setmetatable({
		_ref = man;
		_cons = {};
		_isPaused = false;

		TimeFunction = os.clock;

		PreRender = Callbacks.new();
		PostSimulation = Callbacks.new();
		PreSimulation = Callbacks.new();
		Defer = Callbacks.new();
	}, BindingExtension)

	self:Init()

	return self
end

function BindingExtension:DisconnectFromRunService()
	for _, con in pairs(self._cons) do
		con:Disconnect()
	end
end

function BindingExtension:Init()
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

function BindingExtension:_connectAtPriority(binding, priority, handler)
	local con = self[EVENT_MAP[binding] or binding]:ConnectAtPriority(priority, handler)
	return function()
		con:Disconnect()
	end
end

function BindingExtension:Connect(binding, handler)
	return self:_connectAtPriority(binding, 0, handler)
end

function BindingExtension:ToFunction(name)
	local method = self[name] or error("No method named " .. name)
	return function(...)
		return method(self, ...)
	end
end

function BindingExtension:Wait(value)
	local timestamp = self:GetTime()
	local co = coroutine.running()

	local disconnect
	local con
	local function destruct()
		disconnect()
		con:Disconnect()
	end

	disconnect = self:_connectAtPriority("Defer", 5, function()
		if isDestroyed(value) then
			destruct()
			return
		end

		local delta = self:GetTime() - timestamp
		if delta >= (extractValue(value) or 0) then
			destruct()
			task.spawn(co, delta)
		end
	end)

	con = self._ref:On("Destroying", disconnect)

	return coroutine.yield()
end

function BindingExtension:Delay(value, handler)
	local timestamp = self:GetTime()

	local disconnect
	local con
	local function destruct()
		disconnect()
		con:Disconnect()
	end

	disconnect = self:_connectAtPriority("Defer", 5, function()
		if isDestroyed(value) then
			destruct()
			return
		end

		local delta = self:GetTime() - timestamp
		if delta >= (extractValue(value) or 0) then
			destruct()
			handler(delta)
		end
	end)

	con = self._ref:On("Destroying", disconnect)

	return destruct
end

function BindingExtension:PauseWrap(handler)
	return function(...)
		if self._isPaused then return end
		handler(...)
	end
end

function BindingExtension:IsPaused()
	return self._isPaused
end

function BindingExtension:Pause()
	if self._isPaused then return end
	self._isPaused = true
	self._ref:Fire("Paused")
end

function BindingExtension:Unpause()
	if not self._isPaused then return end
	self._isPaused = false
	self._ref:Fire("Unpaused")
end

function BindingExtension:GetTime()
	return self.TimeFunction()
end

return BindingExtension