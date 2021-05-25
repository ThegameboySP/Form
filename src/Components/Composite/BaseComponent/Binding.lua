local RunService = game:GetService("RunService")

local Maid = require(script.Parent.Parent.Parent.Modules.Maid)

local Binding = {}
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

	local tbl = binding == nil and self._testBound or self._testBound[binding] or {}
	for _, handlers in pairs(tbl) do
		for _, handler in ipairs(handlers) do
			handler(delta)
		end
	end
end


function Binding:Connect(binding, handler)
	if not self._base.isTesting then
		local resolvedBinding = EVENT_MAP[binding] or binding
		return RunService[resolvedBinding]:Connect(self._base.Pause:Wrap(handler))
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
		local con, id = self:Bind("PostSimulation", function()
			destruct()
			handler(table.unpack(args, 1, argLen))
		end)
		destruct = function()
			if not con.Connected then return end
			self._maid:Remove(id)
		end

		return destruct
	else
		handler(...)
		return NOOP
	end
end

return Binding