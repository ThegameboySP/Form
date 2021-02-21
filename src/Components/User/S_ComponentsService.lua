local ReplicatedStorage = game:GetService("ReplicatedStorage")

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


function ServerComponentsService:GetManager(manName)
	return self._managers[manName]
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

	local man = ComponentsManager.new()
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

	entryFdr.Parent = self._manFdr

	-- Client can get the public members from the instance.
	man.ComponentAdded:Connect(function(instance, name, props, groups)
		local module = self._srcs[name]
		if module.NetworkMode == ComponentsManager.NetworkMode.SERVER_CLIENT then
			print("Add replicating", instance, name)

			local tag = Instance.new("BoolValue")
			tag.Name = "ServerComponent"
			tag.Archivable = false
			tag.Value = true
			tag.Parent = instance

			addCompRemote:FireAllClients(instance, name, props, groups)
		end
	end)

	man.ComponentRemoved:Connect(function(instance, name)
		local module = self._srcs[name]
		if module.NetworkMode == ComponentsManager.NetworkMode.SERVER_CLIENT then
			print("Remove replicating", instance, name)
			removeCompRemote:FireAllClients(instance, name)
		end
	end)

	return man
end


function ServerComponentsService:RegisterComponent(src)
	local name = src.ComponentName
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
			if src.ComponentName:sub(1, 2) == "C_" then continue end

			self:RegisterComponent(src)
		elseif instance:IsA("Folder") then
			self:RegisterComponentsInFolder(instance)
		end
	end
end

return ServerComponentsService.new()