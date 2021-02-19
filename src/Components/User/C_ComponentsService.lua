local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

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

	local man = ComponentsManager.new()
	self._managers[manName] = man
	for name, src in next, self._srcs do
		man:RegisterComponent(name, src)
	end

	local entryFdr = ReplicatedStorage:WaitForChild("ComponentsManagers"):WaitForChild(manName)
	local addCompRemote = entryFdr:WaitForChild("ComponentAdded")
	local removeCompRemote = entryFdr:WaitForChild("ComponentRemoved")

	man.ComponentAdded:Connect(function(instance, name)
		local cloneProfile = man:getCloneProfile(instance)
		local prototype = cloneProfile.prototype.instance
		if not CollectionService:HasTag(prototype, "ServerComponent") then return end

		-- Since replication happens in order, we should never have to wait for this.
		local fdr = prototype.ComponentsPublic
		local stateFdr = fdr:FindFirstChild(name)

		ComponentsUtils.subscribeState(stateFdr, function(property, value)
			man:SetState(instance, name, {[property.Name] = value})
		end)

		ComponentsUtils.subscribeGroups(prototype, function(group, exists)
			if exists then
				print("Adding group", instance, group.Name)
				man:AddToGroup(instance, group.Name)
			else
				print("Removing group", instance, group.Name)
				man:RemoveFromGroup(instance, group.Name)
			end
		end)
	end)

	addCompRemote.OnClientEvent:Connect(function(instance, name, props, groups)
		print("Added", instance, name)
		instance.Parent = game.ReplicatedStorage
		man:AddComponent(instance, name, props, groups, true)
	end)

	removeCompRemote.OnClientEvent:Connect(function(instance, name)
		print("Removed", instance, name)
		man:RemoveComponent(instance, name)
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

return ClientComponentsService.new()