local getOrMake = require(script.Parent.Parent.Parent.Form.getOrMake)

local RemoteExtension = {}
RemoteExtension.__index = RemoteExtension

function RemoteExtension.new(man)
	return setmetatable({
		man = man;
		_compFunctions = setmetatable({}, {__mode = "k"});
		_event = getOrMake(man.Folder, "GlobalRemoteEvent", "RemoteEvent");
		_function = getOrMake(man.Folder, "GlobalRemoteFunction", "RemoteFunction");
	}, RemoteExtension)
end

function RemoteExtension:Init()
	if self.man.IsServer then
		self.man:On("ComponentAdding", function(comp)
			local remoteFunctions = comp:GetClass().Remote
			if remoteFunctions == nil then return end
			
			for name, handler in pairs(remoteFunctions) do
				self:OnInvoke(name, handler)
			end
		end)

		self._event.OnServerEvent:Connect(function(ref, className, eventName, ...)
			if type(eventName) ~= "string" then return end
			local comp = self.man:GetComponent(ref, className)
			if comp == nil then return end

			comp:Fire("Client" .. eventName, ...)
		end)

		self._function.OnInvoke = function(player, ref, className, funcName, ...)
			if type(funcName) ~= "string" then return end
			local comp = self.man:GetComponent(ref, className)
			if comp == nil then return end

			local functions = self._compFunctions[comp]
			if functions == nil then return end
			local func = functions[funcName]
			if func == nil then return end

			func(comp, player, ...)
		end
	else
		-- Defer in case remotes are already queued. This runs after Replication's Defer does.
		self.man.Binding.Defer:ConnectAtPriority(1, function()
			self._event.OnClientEvent:Connect(function(ref, className, eventName, ...)
				if type(eventName) ~= "string" then return end
				local comp = self.man:GetComponent(ref, className)
				if comp == nil then return end
	
				comp:Fire("Server" .. eventName, ...)
			end)
		end)
	end
end

function RemoteExtension:FireServer(comp, eventName, ...)
	assert(not self.man.IsServer, "FireServer can only be used on the client!")
	self._event:FireServer(comp.ref, comp.ClassName, eventName, ...)
end

function RemoteExtension:FireAllClients(comp, eventName, ...)
	assert(self.man.IsServer, "FireAllClients can only be called on the server!")
	self._event:FireAllClients(comp.ref, comp.ClassName, eventName, ...)
end

function RemoteExtension:FireClient(comp, eventName, client, ...)
	assert(self.man.IsServer, "FireClient can only be called on the server!")
	self._event:FireClient(client, comp.ref, comp.ClassName, eventName, ...)
end

function RemoteExtension:_setFunctionInvoke(comp, funcName, handler)
	local compFunctions = self._compFunctions[comp]
	if compFunctions == nil then
		compFunctions = {}
		self._compFunctions[comp] = compFunctions
	end

	self._compFunctions[funcName] = handler
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

		handler(...)
	end)
end

function RemoteExtension:Invoke(comp, funcName, ...)
	assert(not self.man.IsServer, "Invoke can only be called on the client!")
	self._function:InvokeServer(comp.ref, comp.ClassName, funcName, ...)
end

return RemoteExtension