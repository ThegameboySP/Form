local BindingExtension = require(script.Parent.BindingExtension)

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
		_ref = base;
		_destructors = {};
		_extension = base.man.Binding;
		_isPaused = false;
	}, BindingEmbedded)

	base:OnAlways("Destroying", function()
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

function BindingEmbedded:_connectAtPriority(binding, priority, handler)
	handler = self:PauseWrap(handler)
	local resolvedBinding = self._ref[EVENT_MAP[binding] or binding]
	
	if resolvedBinding then
		local con = resolvedBinding:ConnectAtPriority(priority, handler)
		return function()
			con:Disconnect()
		end
	end

	return self._ref.man.Binding:_connectAtPriority(binding, priority, handler)
end

function BindingEmbedded:Connect(binding, handler)
	return self:_connectAtPriority(binding, 0, handler)
end

function BindingEmbedded:Bind(binding, handler)
	local destruct = self:Connect(binding, handler)
	self._destructors[destruct] = true
	
	return function()
		self._destructors[destruct] = nil
		destruct()
	end
end

BindingEmbedded.Wait = BindingExtension.Wait
BindingEmbedded.Delay = BindingExtension.Delay
BindingEmbedded.ToFunction = BindingExtension.ToFunction
BindingEmbedded.PauseWrap = BindingExtension.PauseWrap
BindingEmbedded.IsPaused = BindingExtension.IsPaused
BindingEmbedded.Pause = BindingExtension.Pause
BindingEmbedded.Unpause = BindingExtension.Unpause

function BindingEmbedded:GetTime()
	local timeFunction = self._ref.TimeFunction
	return
		timeFunction and timeFunction()
		or self._extension:GetTime()
end

return BindingEmbedded