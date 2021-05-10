local runCoroutineOrWarn = require(script.Parent.runCoroutineOrWarn)

local SignalMixin = {}

local ERROR = "Listener errored: %s\nTraceback: %s"

function SignalMixin.wrap(class)
	function class:On(name, handler)
		self._listeners[name] = self._listeners[name] or {}
		local listeners = self._listeners[name]
		table.insert(listeners, handler)
	
		return function()
			local i = table.find(listeners, handler)
			if i == nil then return end
			table.remove(listeners, i)
		end
	end
	
	
	function class:OnAny(handler)
		table.insert(self._anyListeners, handler)
		
		return function()
			local i = table.find(self._anyListeners, handler)
			if i == nil then return end
			table.remove(self._anyListeners, i)
		end
	end
	
	
	function class:Fire(name, ...)
		local tables = {self._listeners[name]}
		table.insert(tables, self._anyListeners)
	
		for _, listeners in ipairs(tables) do
			for _, handler in ipairs(listeners) do
				runCoroutineOrWarn(ERROR, handler, ...)
			end
		end
	end

	function class:DisconnectAll()
		table.clear(self._listeners)
		table.clear(self._anyListeners)
	end

	return class
end

function SignalMixin.new(self)
	self._listeners = {}
	self._anyListeners = {}
	return self
end

return SignalMixin