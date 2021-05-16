local RunService = game:GetService("RunService")

local Maid = require(script.Parent.Parent.Parent.Modules.Maid)

local Binding = {
	PostSimulation = "PostSimulation";
	PreRender = "PreRender";
}
Binding.__index = Binding

local NOOP = function() end

function Binding.new(base)
	return setmetatable({
		_base = base;
		_maid = Maid.new();
	}, Binding)
end


function Binding:Destroy()
	self._maid:DoCleaning()
end


function Binding:Connect(binding, handler)
	return RunService[binding]:Connect(handler)
end


function Binding:Bind(binding, handler)
	return self._maid:Add(self:Connect(binding, handler))
end


function Binding:SpawnNextFrame(handler, ...)
	if not self._base.isTesting then
		local args = {...}
		local argLen = #args

		local id
		id = self._maid:GiveTask(RunService.Heartbeat:Connect(function()
			self._maid[id] = nil
			handler(table.unpack(args, 1, argLen))
		end))
		
		return id
	else
		handler()
		return NOOP
	end
end

return Binding