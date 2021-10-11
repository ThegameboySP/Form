local ExtensionPrototype = {}
ExtensionPrototype.__index = ExtensionPrototype

function ExtensionPrototype.new(man)
	local self = setmetatable({
		_man = man;
		pending = {};
		_isDestroyed = false;
	}, ExtensionPrototype)

	if man.IsRunning then
		task.delay(0, task.defer, ExtensionPrototype._update, self)
	end

	return self
end

function ExtensionPrototype:Destroy()
	self._isDestroyed = true
end

function ExtensionPrototype:_update()
	if self._isDestroyed then return end

	for data in pairs(self.pending) do
		data:onUpdate()
	end

	table.clear(self.pending)
	task.delay(0, task.defer, ExtensionPrototype._update, self)
end

return ExtensionPrototype