local RunService = game:GetService("RunService")

local Binding = {}
Binding.ClassName = "BindingExtension"
Binding.__index = Binding

local EVENT_MAP = {
	Heartbeat = "PostSimulation";
	RenderStepped = "PreRender";
	Stepped = "PreSimulation";
}

function Binding.new(man)
	return setmetatable({
		_man = man;
		_testBound = {};
		
		TimeFunction = tick;

		PreRender = RunService.RenderStepped;
		PostSimulation = RunService.Heartbeat;
		PreSimulation = RunService.Stepped;
	}, Binding)
end


function Binding:Destroy()
	table.clear(self._testBound)
end


-- For unit testing.
function Binding:_advance(delta, binding)
	assert(self._man.IsTesting, "Component is not testing!")
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
	if not self._man.IsTesting then
		local resolvedBinding = EVENT_MAP[binding] or binding
		local con = self[resolvedBinding]:Connect(handler)

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


function Binding:GetTime()
	return self.TimeFunction()
end

return Binding