local RemoteEmbedded = {}
RemoteEmbedded.ClassName = "Remote"
RemoteEmbedded.__index = RemoteEmbedded

function RemoteEmbedded.new(base)
	return setmetatable({
		_base = base;
		_extension = base.man.Remote;
	}, RemoteEmbedded)
end

function RemoteEmbedded:RegisterEvents(events)
	return self._extension:RegisterEvents(self._base, events)
end

function RemoteEmbedded:RegisterFunctions(funcs)
	return self._extension:RegisterFunctions(self._base, funcs)
end

function RemoteEmbedded:Connect(eventName, handler)
	return self._extension:Connect(self._base, eventName, handler)
end

function RemoteEmbedded:FireServer(eventName, ...)
	return self._extension:FireServer(self._base, eventName, ...)
end

function RemoteEmbedded:FireAllClients(eventName, ...)
	return self._extension:FireAllClients(self._base, eventName, ...)
end

function RemoteEmbedded:FireClient(eventName, client, ...)
	return self._extension:FireClient(self._base, eventName, client, ...)
end

function RemoteEmbedded:OnInvoke(funcName, handler)
	return self._extension:OnInvoke(self._base, funcName, handler)
end

function RemoteEmbedded:Invoke(funcName, ...)
	return self._extension:Invoke(self._base, funcName, ...)
end

return RemoteEmbedded