local Hooks = {}
Hooks.__index = Hooks

local Connection = {}
Connection.__index = Connection

local function newConnection(hook, name, handler, first)
	return setmetatable({
		_hook = hook;
		_name = name;
		_handler = handler;
		_next = first;
	}, Connection)
end

function Connection:Disconnect()
	if self._hook == false then
		error("Can't disconnect a connection twice.", 2)
	end

	local head = self._hook[self._name]
	if head == self then
		self._hook[self._name] = self._next
	else
		local prev = head
		while prev and prev._next ~= self do
			prev = prev._next
		end

		if prev then
			prev._next = self._next
		end
	end

	self._hook = false
end
Connection.Destroy = Connection.Disconnect

function Hooks.new()
	return setmetatable({}, Hooks)
end

function Hooks:On(name, handler)
	local first = rawget(self, name)
	if first then
		local connection = newConnection(self, name, handler, first)
		self[name] = connection

		return connection
	end

	local connection = newConnection(self, name, handler)
	self[name] = connection
	return connection
end

function Hooks:OnAlways(name, handler)
	self[name] = {_handler = handler, _next = rawget(self, name)}
end

function Hooks:Fire(name, ...)
	local hook = rawget(self, name)
	while hook do
		hook._handler(...)
		hook = hook._next
	end
end

function Hooks:DisconnectFor(name)
	self[name] = nil
end

function Hooks:DisconnectAll()
	table.clear(self)
end
Hooks.Destroy = Hooks.DisconnectAll

function Hooks:WaitFor(name)
	local co = coroutine.running()
	local con
	con = self:On(name, function(...)
		con:Disconnect()
		task.spawn(co, ...)
	end)
	
	return coroutine.yield()
end

return Hooks