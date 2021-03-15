local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local ComponentsManager = require(script.Parent.Parent.ComponentsManager)
local NetworkMode = ComponentsManager.NetworkMode
local ComponentsUtils = require(script.Parent.Parent.ComponentsUtils)

local ClientComponentsService = {}
ClientComponentsService.__index = ClientComponentsService

local ADD_COMPONENT_KEYWORDS = {componentMode = "Overlay"}

function ClientComponentsService.new()
	local self
	self = setmetatable({
		_managers = {};
		_srcs = {};
		_filter = function(instance, tag)
			if ComponentsUtils.getAncestorInstanceTag(instance, "OnlyServer") then
				return false
			end

			local src = self._srcs[tag]
			if src == nil then return false end

			local isServerComponent = CollectionService:HasTag(instance, "ServerComponent")
			if isServerComponent and src.NetworkMode == NetworkMode.SERVER_CLIENT then
				return true
			end

			if src.NetworkMode == NetworkMode.SHARED or src.NetworkMode == NetworkMode.CLIENT then
				return true
			end

			return false
		end
	}, ClientComponentsService)

	return self
end


function ClientComponentsService:Stop()
	for _, man in next, self._managers do
		man:Stop()
	end
end


function ClientComponentsService:GetManager(manName)
	return self._managers[manName]
end


function ClientComponentsService:AddManager(manName)
	if self._managers[manName] then
		error(("There is already a manager by the name %q!"):format(manName))
	end

	local man = ComponentsManager.new(self._filter)

	self._managers[manName] = man
	for _, src in next, self._srcs do
		man:RegisterComponent(src)
	end

	local entryFdr = ReplicatedStorage:WaitForChild("ComponentsManagers"):WaitForChild(manName)
	local addCompRemote = entryFdr:WaitForChild("ComponentAdded")
	local removeCompRemote = entryFdr:WaitForChild("ComponentRemoved")
	local cloneRemovedRemote = entryFdr:WaitForChild("CloneRemoved")

	-- Since replication happens in order, and ComponentAdded fires last, 
	-- we should never have to wait for required instances.
	addCompRemote.OnClientEvent:Connect(function(instance, name, config, groups)
		local compName = ComponentsUtils.getBaseComponentName(name)
		if not self._filter(instance, compName) then return end
		
		local moduleName
		if self._srcs[compName] then
			moduleName = compName
		else
			return
		end

		-- print("Adding", instance, moduleName)
		man:AddComponent(instance, moduleName, config, ADD_COMPONENT_KEYWORDS, groups)
	end)

	removeCompRemote.OnClientEvent:Connect(function(instance, name)
		local compName = ComponentsUtils.getBaseComponentName(name)
		local moduleName
		if self._srcs[compName] then
			moduleName = compName
		else
			return
		end

		-- print("Removing", instance, moduleName)
		man:RemoveComponent(instance, moduleName)
	end)

	cloneRemovedRemote.OnClientEvent:Connect(function(clone)
		man:RemoveClone(clone)
	end)

	return man
end


function ClientComponentsService:RegisterComponent(src)
	local name = src.ComponentName
	if name == nil then return end
	
	assert(name:sub(1, 2) ~= "S_", "Cannot register a server component on the client!")
	local compName = ComponentsUtils.getBaseComponentName(name)
	assert(self._srcs[compName] == nil, "Already registered component!")

	for _, manager in next, self._managers do
		manager:RegisterComponent(src)
	end

	self._srcs[compName] = src
end


function ClientComponentsService:RegisterComponentsInFolder(folder)
	for _, instance in next, folder:GetChildren() do
		if instance:IsA("ModuleScript") then
			local src = require(instance)
			if src.ComponentName == nil then continue end
			if src.ComponentName:sub(1, 2) == "S_" then continue end

			self:RegisterComponent(src)
		elseif instance:IsA("Folder") then
			self:RegisterComponentsInFolder(instance)
		end
	end
end

return ClientComponentsService.new()