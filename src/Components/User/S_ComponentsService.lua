local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local ComponentsManager = require(script.Parent.Parent.ComponentsManager)
local ComponentsUtils = require(script.Parent.Parent.ComponentsUtils)

local ServerComponentsService = {}
ServerComponentsService.__index = ServerComponentsService

function ServerComponentsService.new()
	return setmetatable({
		_manFdr = nil;

		_managers = {};
		_srcs = {};
	}, ServerComponentsService)
end


function ServerComponentsService:Stop()
	for _, man in next, self._managers do
		man:Stop()
	end
end


function ServerComponentsService:GetManager(manName)
	return self._managers[manName]
end


function ServerComponentsService:GetManagers()
	return self._managers
end


function ServerComponentsService:AddManager(manName)
	if self._managers[manName] then
		error(("There is already a manager by the name %q!"):format(manName))
	end
	
	if self._manFdr == nil then
		local manFdr = Instance.new("Folder")
		manFdr.Name = "ComponentsManagers"
		manFdr.Parent = ReplicatedStorage
		self._manFdr = manFdr
	end

	local man = ComponentsManager.new(function(instance, tag)
		local src = self._srcs[tag]
		return src.NetworkMode ~= ComponentsManager.NetworkMode.CLIENT
			and not ComponentsUtils.getAncestorInstanceTag(instance, "OnlyClient")
	end)
	
	self._managers[manName] = man
	for _, src in next, self._srcs do
		man:RegisterComponent(src)
	end

	local entryFdr = Instance.new("Folder")
	entryFdr.Name = manName
	
	local addCompRemote = Instance.new("RemoteEvent")
	addCompRemote.Name = "ComponentAdded"
	addCompRemote.Parent = entryFdr

	local removeCompRemote = Instance.new("RemoteEvent")
	removeCompRemote.Name = "ComponentRemoved"
	removeCompRemote.Parent = entryFdr

	local cloneRemovedRemote = Instance.new("RemoteEvent")
	cloneRemovedRemote.Name = "CloneRemoved"
	cloneRemovedRemote.Parent = entryFdr

	entryFdr.Parent = self._manFdr

	-- Client can get the public members from the instance.
	man.ComponentAdded:Connect(function(instance, name, config, groups)
		local module = self._srcs[name]
		if module.NetworkMode ~= ComponentsManager.NetworkMode.CLIENT then
			-- print("Add replicating", instance, name)
			CollectionService:AddTag(instance, "ServerComponent")

			addCompRemote:FireAllClients(instance, name, config, groups)
		end
	end)

	man.ComponentRemoved:Connect(function(instance, name)
		local module = self._srcs[name]
		if module.NetworkMode ~= ComponentsManager.NetworkMode.CLIENT then
			-- print("Remove replicating", instance, name)
			removeCompRemote:FireAllClients(instance, name)
		end
	end)

	man.ComponentRemoved:Connect(function(clone)
		cloneRemovedRemote:FireAllClients(clone)
	end)

	return man
end


function ServerComponentsService:RegisterComponent(src)
	local name = src.ComponentName
	if name == nil then return end
	assert(name:sub(1, 2) ~= "C_", "Cannot register a client component on the server!")

	local compName = ComponentsUtils.getBaseComponentName(name)
	assert(self._srcs[compName] == nil, "Already registered component!")

	for _, manager in next, self._managers do
		manager:RegisterComponent(src)
	end

	self._srcs[compName] = src
end


function ServerComponentsService:RegisterComponentsInFolder(folder)
	for _, instance in next, folder:GetChildren() do
		if instance:IsA("ModuleScript") then
			local src = require(instance)
			if src.ComponentName == nil then continue end
			if src.ComponentName:sub(1, 2) == "C_" then continue end

			self:RegisterComponent(src)
		elseif instance:IsA("Folder") then
			self:RegisterComponentsInFolder(instance)
		end
	end
end

return ServerComponentsService.new()