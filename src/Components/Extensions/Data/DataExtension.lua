local RunService = game:GetService("RunService")

local ExtensionPrototype = {}
ExtensionPrototype.__index = ExtensionPrototype

function ExtensionPrototype.new(man)
	local self = setmetatable({
		_man = man;
		_pending = {};
		_con = nil;
	}, ExtensionPrototype)

	if man.IsRunning then
		self._con = RunService.Heartbeat:Connect(function()
			self:_update()
		end)
	end

	return self
end

function ExtensionPrototype:Destroy()
	if self._con then
		self._con:Disconnect()
	end
end

function ExtensionPrototype:_update()
	for data, keys in pairs(self._pending) do
		local final = data.final

		for key in pairs(keys) do
			local value = data:Get(key)
			if final[key] ~= value then
				keys[key] = value
			end
		end

		data:onDelta(keys)
	end

	table.clear(self._pending)
end

function ExtensionPrototype:SetDirty(data, key)
	local entry = self._pending[data]
	if entry == nil then
		entry = {}
		self._pending[data] = entry
	end

	entry[key] = true
end

return ExtensionPrototype