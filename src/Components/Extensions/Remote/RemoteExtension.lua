local getOrMake = require(script.Parent.Parent.Parent.Form.getOrMake)

local RemoteExtension = {}
RemoteExtension.__index = RemoteExtension

function RemoteExtension.new(man, overrides)
	return setmetatable({
		man = man;
		_compFunctions = setmetatable({}, {__mode = "k"});
		_event = overrides and overrides.event or getOrMake(man.Folder, "GlobalRemoteEvent", "RemoteEvent");
		_function = overrides and overrides.callback or getOrMake(man.Folder, "GlobalRemoteFunction", "RemoteFunction");
	}, RemoteExtension)
end

function RemoteExtension:Init()
	if self.man.IsServer then
		self.man:On("ComponentAdding", function(comp)
			local remoteFunctions = comp:GetClass().Remote
			if remoteFunctions == nil then return end
			
			for name, handler in pairs(remoteFunctions) do
				self:OnInvoke(comp, name, handler)
			end
		end)

		self._event.OnServerEvent:Connect(function(player, serializedComp, eventName, ...)
			if type(eventName) ~= "string" then return end

			local comp = self:_getOrWarn(serializedComp)
			if comp == nil then return end

			comp:Fire("Client" .. eventName, player, ...)
		end)

		self._function.OnServerInvoke = function(player, serializedComp, funcName, ...)
			if type(funcName) ~= "string" then return end

			local comp = self:_getOrWarn(serializedComp)
			if comp == nil then return end
			
			local functions = self._compFunctions[comp]
			if functions == nil then return end
			local func = functions[funcName]
			if func == nil then return end

			return func(comp, player, ...)
		end
	else
		-- Defer in case remotes are already queued. This runs after Replication's Defer does.
		local con
		con = self.man.Binding.Defer:ConnectAtPriority(1, function()
			con:Disconnect()
			
			self._event.OnClientEvent:Connect(function(serializedComp, eventName, ...)
				if type(eventName) ~= "string" then return end

				local comp = self:_getOrWarn(serializedComp)
				if comp == nil then return end

				comp:Fire("Server" .. eventName, ...)
			end)
		end)
	end
end

function RemoteExtension:_getOrWarn(serializedComp)
	local comp = self.man.Serializers:Deserialize(serializedComp)
	if comp == nil then
		local extracted = self.man.Serializers:Extract(serializedComp)
		self.man:DebugPrint("Component %s of %s does not exist on %s"):format(
			extracted.name,
			extracted.ref:GetFullName(),
			self.man.IsServer and "server" or "client"
		)
		
		return
	end

	return comp
end

function RemoteExtension:FireServer(comp, eventName, ...)
	assert(not self.man.IsServer, "FireServer can only be used on the client!")
	self._event:FireServer(self.man.Serializers:Serialize(comp), eventName, ...)
end

function RemoteExtension:FireAllClients(comp, eventName, ...)
	assert(self.man.IsServer, "FireAllClients can only be called on the server!")
	self._event:FireAllClients(self.man.Serializers:Serialize(comp), eventName, ...)
end

function RemoteExtension:FireClient(comp, eventName, client, ...)
	assert(self.man.IsServer, "FireClient can only be called on the server!")
	self._event:FireClient(client, self.man.Serializers:Serialize(comp), eventName, ...)
end

function RemoteExtension:_setFunctionInvoke(comp, funcName, handler)
	local compFunctions = self._compFunctions[comp]
	if compFunctions == nil then
		compFunctions = {}
		self._compFunctions[comp] = compFunctions
	end

	compFunctions[funcName] = handler
end

function RemoteExtension:OnInvoke(comp, funcName, handler)
	assert(self.man.IsServer, "OnInvoke can only be called on the server!")
	
	local initial = true
	self:_setFunctionInvoke(comp, funcName, function(...)
		if initial then
			initial = false
			
			local co = coroutine.running()
			task.defer(task.spawn, co)
			coroutine.yield()
		end

		return handler(...)
	end)
end

function RemoteExtension:Invoke(comp, funcName, ...)
	assert(not self.man.IsServer, "Invoke can only be called on the client!")
	return self._function:InvokeServer(self.man.Serializers:Serialize(comp), funcName, ...)
end

return RemoteExtension