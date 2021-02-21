local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ComponentsManager = require(script.Parent.Parent.ComponentsManager)
local ComponentsUtils = require(script.Parent.Parent.ComponentsUtils)

local ClientComponentsService = {}
ClientComponentsService.__index = ClientComponentsService

function ClientComponentsService.new()
	return setmetatable({
		_managers = {};
		_srcs = {};
	}, ClientComponentsService)
end


function ClientComponentsService:GetManager(manName)
	return self._managers[manName]
end


function ClientComponentsService:AddManager(manName)
	if self._managers[manName] then
		error(("There is already a manager by the name %q!"):format(manName))
	end

	local man = ComponentsManager.new(function(prototype)
		return prototype:FindFirstChild("ServerComponent") ~= nil
	end)

	self._managers[manName] = man
	for _, src in next, self._srcs do
		man:RegisterComponent(src)
	end

	local entryFdr = ReplicatedStorage:WaitForChild("ComponentsManagers"):WaitForChild(manName)
	local addCompRemote = entryFdr:WaitForChild("ComponentAdded")
	local removeCompRemote = entryFdr:WaitForChild("ComponentRemoved")

	-- Since replication happens in order, and ComponentAdded fires last, 
	-- we should never have to wait for required instances.
	addCompRemote.OnClientEvent:Connect(function(instance, name, props, groups)
		local compName = ComponentsUtils.getBaseComponentName(name)
		local clientName = "C_" .. compName
		local moduleName
		if self._srcs[clientName] then
			moduleName = clientName
		elseif compName and self._srcs[compName] then
			moduleName = compName
		else
			return
		end

		print("Adding", instance, moduleName)
		man:AddComponent(instance, moduleName, props, groups, true)
	end)

	removeCompRemote.OnClientEvent:Connect(function(instance, name)
		local compName = ComponentsUtils.getBaseComponentName(name)
		local clientName = "C_" .. compName
		local moduleName
		if self._srcs[clientName] then
			moduleName = clientName
		elseif self._srcs[compName] then
			moduleName = compName
		else
			return
		end

		print("Removing", instance, moduleName)
		man:RemoveComponent(instance, moduleName)
	end)

	return man
end


function ClientComponentsService:RegisterComponent(src)
	local name = src.ComponentName
	assert(name:sub(1, 2) ~= "S_", "Cannot register a server component on the client!")
	assert(self._srcs[name] == nil, "Already registered component!")

	for _, manager in next, self._managers do
		manager:RegisterComponent(src)
	end

	self._srcs[name] = src
end


function ClientComponentsService:RegisterComponentsInFolder(folder)
	for _, instance in next, folder:GetChildren() do
		if instance:IsA("ModuleScript") then
			local src = require(instance)
			if src.ComponentName:sub(1, 2) == "S_" then continue end

			self:RegisterComponent(src)
		elseif instance:IsA("Folder") then
			self:RegisterComponentsInFolder(instance)
		end
	end
end

return ClientComponentsService.new()