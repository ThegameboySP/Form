local Data = require(script.Data)
local Symbol = require(script.Parent.Parent.Modules.Symbol)

local ExtensionPrototype = {}
ExtensionPrototype.__index = ExtensionPrototype

local NULL = Symbol.new("null")

function ExtensionPrototype.new(man)
	local self = setmetatable({
		_man = man;
		_isDestroyed = false;
		_pending = {};
	}, ExtensionPrototype)

	if man.IsRunning then
		task.delay(0, task.defer, self._update, self)
	end

	return self
end

function ExtensionPrototype:Destroy()
	self._isDestroyed = true
end

function ExtensionPrototype:_update()
	if self._isDestroyed then return end

	table.clear(self._pending)

	task.delay(0, task.defer, self._update, self)
end

function ExtensionPrototype:SetDirty(comp, key, oldValue)
	local entry = self._pending[comp]
	if entry == nil then
		entry = {}
		self._pending[comp] = entry
	end

	if entry[key] == nil then
		if oldValue == nil then
			entry[key] = NULL
		else
			entry[key] = oldValue
		end
	end
end

return function(man)
	local extension = ExtensionPrototype.new(man)
	man.Data = extension

	man:RegisterEmbedded({
		ClassName = "Data";
		new = function(comp)
			local data = Data.new(extension, comp, comp.Schema)

			if comp.Defaults then
				data:_insert("default", comp.Defaults)
			end

			if not man.IsServer and comp.NetworkMode == "ServerClient" then
				data:_insert("remote", {})
			end
			
			data:_insert("base", {})

			return data
		end;
	})
end