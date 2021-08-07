local RunService = game:GetService("RunService")

local Maid = require(script.Parent.Parent.Parent.Modules.Maid)

local Binding = {}
Binding.ClassName = "Binding"
Binding.__index = Binding

local EVENT_MAP = {
	PostSimulation = "Heartbeat";
	PreRender = "RenderStepped";
	PreSimulation = "Stepped";
}
local NOOP = function() end

function Binding.new(base)
	return setmetatable({
		_base = base;
		_maid = Maid.new();
		_testBound = {};

		_signals = {
			Heartbeat = base.PostSimulation or RunService.Heartbeat;
			RenderStepped = base.PreRender or RunService.RenderStepped;
			Stepped = base.PreSimulation or RunService.Stepped;
		};
	}, Binding)
end


function Binding:Destroy()
	self._maid:DoCleaning()
	table.clear(self._testBound)
end


-- For unit testing.
function Binding:_advance(delta, binding)
	assert(self._base.isTesting, "Component is not testing!")
	delta = delta or (1 / 60)

	local tbls = self._testBound
	if binding then
		tbls = {self._testBound[binding] or {}}
	end
	
	for _, tbl in pairs(tbls) do
		for _, handler in pairs(tbl) do
			handler(delta)
		end
	end
end


function Binding:Connect(binding, handler)
	if not self._base.isTesting then
		local resolvedBinding = EVENT_MAP[binding] or binding
		local con = self._signals[resolvedBinding]:Connect(handler)

		return function()
			con:Disconnect()
		end
	else
		self._testBound[binding] = self._testBound[binding] or {}
		local handlers = self._testBound[binding]
		table.insert(handlers, handler)

		return function()
			local index = table.find(handlers, handler)
			if index == nil then return end
			table.remove(handlers, index)
		end
	end
end


function Binding:Bind(binding, handler)
	return (self._maid:AddAuto(self:Connect(binding, handler)))
end


function Binding:SpawnNextFrame(handler, ...)
	if not self._base.isTesting then
		local args = {...}
		local argLen = #args

		local destruct
		local bindDestructor = self:Bind("PostSimulation", function()
			destruct()
			handler(table.unpack(args, 1, argLen))
		end)

		local destructed = false
		destruct = function()
			if destructed then return end
			destructed = true
			bindDestructor()
		end

		return destruct
	else
		handler(...)
		return NOOP
	end
end


function Binding:GetTime()
	local man = self._base.man
	return man and man:GetTime() or tick()
end

return Binding