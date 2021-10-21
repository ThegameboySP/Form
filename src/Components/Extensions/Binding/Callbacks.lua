local Callbacks = {}
Callbacks.__index = Callbacks

local Connection = {}
Connection.__index = Connection

local function newConnection(callbacks, next, handler, priority)
	return setmetatable({
		_callbacks = callbacks;
		_next = next;
		_handler = handler;
		_priority = priority;
	}, Connection)
end

function Connection:Disconnect()
	if self._callbacks == false then
		-- Connection has already been disconnected.
		return
	end

	if self._callbacks._head == self then
		self._callbacks._head = self._next
	else
		local prev = self._callbacks._head
		while prev and prev._next ~= self do
			prev = prev._next
		end

		if prev then
			prev._next = self._next
		end
	end

	self._callbacks = false
end

function Callbacks.new(priority, default)
	local self = setmetatable({
		_head = nil;
	}, Callbacks)

	if priority then
		self:ConnectAtPriority(priority, default)
	end

	return self
end

function Callbacks:ConnectAtPriority(priority, handler)
	assert(type(priority) == "number", "Priority must be a number")

	local handlerType = type(handler)
	if handlerType ~= "function" then
		assert(handlerType == "table", "Handler must be invokable")
		local mt = getmetatable(handler)
		assert(mt and mt.__call, "Handler must be invokable")
	end
	
	local current = self._head
	local prev
	while current do
		if current._priority <= priority then
			local connection = newConnection(self, current, handler, priority)
			if prev then
				prev._next = connection
			end

			if self._head == current then
				self._head = connection
			end

			return connection
		end

		if current._next == nil then
			local connection = newConnection(self, nil, handler, priority)
			current._next = connection

			return connection
		end
		
		prev = current
		current = current._next
	end

	local connection = newConnection(self, nil, handler, priority)
	if self._head == nil then
		self._head = connection
	end

	return connection
end

function Callbacks:Connect(handler)
	return self:ConnectAtPriority(0, handler)
end

function Callbacks:Fire(...)
	local current = self._head
	while current do
		current._handler(...)
		current = current._next
	end
end

function Callbacks:Wait()
	local co = coroutine.running()
	local con
	con = self:Connect(function(...)
		con:Disconnect()
		task.spawn(co, ...)
	end)
	
	return coroutine.yield()
end

return Callbacks