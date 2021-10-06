local RemoteUtils = require(script.Parent.RemoteUtils)

local RemoteExtension = {}
RemoteExtension.__index = RemoteExtension

function RemoteExtension.new(man)
	local self = setmetatable({
		man = man;
	}, RemoteExtension)

	man:On("ComponentAdding", function(comp)
		local events = comp.RemoteEvents
		if events then
			if man.IsServer then
				for _, name in ipairs(events) do
					self:RegisterEvent(comp, name)
				end

				local wrapped = {}
				for name, handler in pairs(events) do
					if type(name) == "string" then
						wrapped[name] = function(...)
							handler(comp, ...)
						end
					end
				end

				self:RegisterEvents(comp, wrapped)
			else
				local wrapped = {}
				for name, handler in pairs(events) do
					if type(name) == "string" then
						wrapped[name] = function(...)
							handler(comp, ...)
						end
					end
				end

				self:ConnectEvents(comp, wrapped)
			end
		end

		local funcs = comp.RemoteFunctions
		if funcs then
			if man.IsServer then
				for _, name in ipairs(funcs) do
					self:RegisterFunction(comp, name)
				end

				local wrapped = {}
				for name, handler in pairs(funcs) do
					if type(name) == "string" then
						wrapped[name] = function(...)
							handler(comp, ...)
						end
					end
				end

				self:RegisterFunctions(comp, wrapped)
			else
				local wrapped = {}
				for name, handler in pairs(funcs) do
					if type(name) == "string" then
						wrapped[name] = function(...)
							handler(comp, ...)
						end
					end
				end

				self:ConnectFunctions(comp, wrapped)
			end
		end
	end)

	return self
end

function RemoteExtension:ConnectEvents(comp, events)
	for eventName, handler in pairs(events) do
		self:Connect(comp, eventName, handler)
	end
end

function RemoteExtension:ConnectFunctions(comp, funcs)
	for funcName, handler in pairs(funcs) do
		self:OnInvoke(comp, funcName, handler)
	end
end

function RemoteExtension:RegisterEvents(comp, events)
	assert(self.man.IsServer, "RegisterEvents can only be used on the server!")

	if events[1] then
		for _, name in pairs(events) do
			RemoteUtils.makeEvent(comp, name)
		end
	else
		for name, handler in pairs(events) do
			RemoteUtils.makeEvent(comp, name)
			self:Connect(comp, name, handler)
		end
	end
end

function RemoteExtension:RegisterFunctions(comp, funcs)
	assert(self.man.IsServer, "RegisterFunctions can only be used on the server!")

	if funcs[1] then
		for _, name in pairs(funcs) do
			RemoteUtils.makeFunction(comp, name)
		end
	else
		for name, handler in pairs(funcs) do
			RemoteUtils.makeEvent(comp, name)
			self:OnInvoke(comp, name, handler)
		end
	end
end

function RemoteExtension:RegisterEvent(comp, name)
	RemoteUtils.makeEvent(comp, name)
end

function RemoteExtension:RegisterFunction(comp, name)
	RemoteUtils.makeFunction(comp, name)
end

function RemoteExtension:Connect(comp, eventName, handler)
	local onEvent = RemoteUtils.initiallyDeferHandler(handler)

	if self.man.IsServer then
		local con = RemoteUtils.getOrError(comp, eventName).OnServerEvent:Connect(onEvent)

		return function()
			con:Disconnect()
		end
	else
		local con
		local promise = RemoteUtils.waitForEvent(comp, eventName, function(remote)
			con = remote.OnClientEvent:Connect(onEvent)
		end)

		return function()
			promise:cancel()
			if con then
				con:Disconnect()
			end
		end
	end
end

function RemoteExtension:FireServer(comp, eventName, ...)
	assert(not self.man.IsServer, "FireServer can only be used on the client!")

	local args = table.pack(...)
	RemoteUtils.waitForEvent(comp, eventName, function(remote)
		remote:FireServer(unpack(args, 1, args.n))
	end)
end

function RemoteExtension:FireAllClients(comp, eventName, ...)
	assert(self.man.IsServer, "FireAllClients can only be called on the server!")
	RemoteUtils.getOrError(comp, eventName):FireAllClients(...)
end

function RemoteExtension:FireClient(comp, eventName, client, ...)
	assert(self.man.IsServer, "FireClient can only be called on the server!")
	RemoteUtils.getOrError(comp, eventName):FireClient(client, ...)
end

function RemoteExtension:OnInvoke(comp, funcName, handler)
	local onInvoke = RemoteUtils.initiallyDeferHandler(handler)

	if self.man.IsServer then
		RemoteUtils.getOrError(comp, funcName).OnServerInvoke = onInvoke
	else
		RemoteUtils.getOrError(comp, funcName).OnClientInvoke = onInvoke
	end
end

function RemoteExtension:Invoke(comp, funcName, ...)
	assert(self.man.IsServer, "Invoke can only be called on the client!")

	local args = table.pack(...)
	return RemoteUtils.waitForFunction(comp, funcName, function(func)
		func:InvokeServer(unpack(args, 1, args.n))
	end)
end

return RemoteExtension