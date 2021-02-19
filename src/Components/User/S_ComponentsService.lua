local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local ComponentsManager = require(script.Parent.Parent.ComponentsManager)

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
	for name, src in next, self._srcs do
		man:RegisterComponent(name, src)
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
		print("Add replicating", instance, name)
		CollectionService:AddTag(instance, "ServerComponent")
		addCompRemote:FireAllClients(instance, name, props, groups)
	end)

	man.ComponentRemoved:Connect(function(instance, name)
		print("Remove replicating", instance, name)
		removeCompRemote:FireAllClients(instance, name)
	end)

	return man
end


function ServerComponentsService:RegisterComponent(src)
	local name = src.ComponentName
	assert(name:sub(1, 2) ~= "C_", "Cannot register a client component on the server!")
	assert(self._srcs[name] == nil, "Already registered component!")

	for _, manager in next, self._managers do
		manager:RegisterComponent(src)
	end

	self._srcs[name] = src
end

return ServerComponentsService.new()