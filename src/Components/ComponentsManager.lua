local CollectionService = game:GetService("CollectionService")

local Components = require(script.Parent.Components)
local ComponentsGroup = require(script.Parent.ComponentsGroup)
local ComponentsUtils = require(script.Parent.ComponentsUtils)
local CloneProfile = require(script.Parent.CloneProfile)
local Event = require(script.Parent.Modules.Event)

local ComponentsManager = {}
ComponentsManager.__index = ComponentsManager
ComponentsManager.NetworkMode = ComponentsUtils.indexTableOrError("NetworkMode", {
	SERVER = 1;
	CLIENT = 2;
	SERVER_CLIENT = 3;
})

-- TODO: make nesting components work

local NOT_DESTRUCTED_ERR = "Behavior not fully destructed!"
local NO_PROFILE_ERR = "No clone profile for %q!"

local RESERVED_COMPONENT_NAMES = {
	Groups = true
}
local FALSE = function() return false end

local function isAllowedToSpawn(prototype, allowedGroups)
	for group in next, prototype.groups do
		if allowedGroups[group] then
			return true
		end
	end

	return false
end

local function getGroups(instance, groups)
	return ComponentsUtils.mergeGroups(
		instance, 
		groups or {Main = true}
	)
end

local function makePrototype(instance, parent, groups)
	return {
		instance = instance;
		parent = parent;
		groups = groups;
	}
end

function ComponentsManager.new(isSyncronizedCallback)
	return setmetatable({
		ComponentAdded = Event.new();
		ComponentRemoved = Event.new();

		_srcs = {};
		_componentHolders = {};

		_time = 0;
		_cloneProfiles = {};
		_prototypes = {};
		_prototypeToClone = {};
		_groups = {};

		_isSyncronizedCallback = isSyncronizedCallback or FALSE
	}, ComponentsManager)
end


function ComponentsManager.generatePrototypesFromRoot(root, tags)
	local prototypes = {}

	for _, tag in next, tags do
		for _, instance in next, {root, unpack( root:GetDescendants() )} do
			if not CollectionService:HasTag(instance, tag) then continue end

			prototypes[instance] = makePrototype(instance, instance.Parent, getGroups(instance, nil))
		end
	end

	return prototypes
end


function ComponentsManager:Destruct()
	for _, holder in next, self._componentHolders do
		holder:Clear()
	end

	for _, destruct in next, self._destructToCloneProfile do
		destruct()
	end

	table.clear(self._cloneProfiles)
	table.clear(self._prototypes)
	table.clear(self._prototypeToClone)
	table.clear(self._groups)
end


function ComponentsManager:Init(root)
	local tags = {}
	for tag in next, self._srcs do
		table.insert(tags, tag)
	end
	local prototypes = self.generatePrototypesFromRoot(root, tags)

	for instance, prototype in next, prototypes do
		-- Check if it's a local clone, as otherwise we may screw up replication or other managers.
		if self:GetCloneProfile(instance) then continue end
		if self._prototypes[instance] then continue end

		CollectionService:AddTag(instance, "Prototype")
		self._prototypes[instance] = prototype

		if instance:FindFirstChild("ComponentsSyncronized") or self._isSyncronizedCallback(instance) then
			self:_newCloneProfile(instance, prototype, true, prototype.groups)
		else
			instance.Parent = nil
			local clone = instance:Clone()
			self:_newCloneProfile(clone, prototype, false, prototype.groups)
		end
	end

	return prototypes
end


function ComponentsManager:RegisterComponent(src)
	local name = src.ComponentName
	assert(type(name) == "string", "Expected 'string'")
	assert(type(src) == "table", "Expected 'table'")

	local baseName = ComponentsUtils.getBaseComponentName(name)
	assert(self._srcs[baseName] == nil, "Already registered component!")
	assert(RESERVED_COMPONENT_NAMES[baseName] == nil, "Name is reserved!")

	self._srcs[baseName] = src

	local holder = Components.new(self, src, baseName)
	self._componentHolders[baseName] = holder

	holder.ComponentAdded:Connect(function(clone, config)
		self.ComponentAdded:Fire(clone, baseName, config, self:GetCloneProfile(clone).prototype.groups)
	end)

	holder.ComponentRemoved:Connect(function(clone)
		self.ComponentRemoved:Fire(clone, baseName)
	end)
end


function ComponentsManager:Reload(root)
	self:Destruct()

	assert(next(self._cloneProfiles) == nil, NOT_DESTRUCTED_ERR)
	assert(next(self._prototypes) == nil, NOT_DESTRUCTED_ERR)
	assert(next(self._prototypeToClone) == nil, NOT_DESTRUCTED_ERR)
	assert(next(self._groups) == nil, NOT_DESTRUCTED_ERR)

	self._prototypes = self:Init(root)
end


function ComponentsManager:RunAndMerge(allowedGroups)
	local newComponents = {}

	for _, prototype in next, self._prototypes do
		if not isAllowedToSpawn(prototype, allowedGroups) then continue end

		local clone = self._prototypeToClone[prototype.instance]
		local cloneProfile = clone and self._cloneProfiles[clone]
		local instance = prototype.instance

		for componentName in next, self._srcs do
			if not CollectionService:HasTag(instance, componentName) then continue end
			if cloneProfile:HasComponent(componentName) then continue end

			clone.Parent = cloneProfile.prototype.parent
			table.insert(newComponents, {
				cloneProfile = cloneProfile;
				componentName = componentName;
			})
		end
	end

	local events = {}
	for _, newComponent in ipairs(newComponents) do
		local cloneProfile = newComponent.cloneProfile
		local clone = cloneProfile.clone
		local name = newComponent.componentName

		local config = self._componentHolders[name]:InitComponent(
			clone, nil, clone:FindFirstChild("ComponentsSyncronized")
		)
		cloneProfile:AddComponent(name)
		table.insert(events, {clone = clone, name = name, config = config})
	end
	
	for _, newComponent in ipairs(newComponents) do
		local cloneProfile = newComponent.cloneProfile
		local clone = cloneProfile.clone
		local name = newComponent.componentName

		self._componentHolders[name]:RunComponentMain(clone)
	end

	for _, event in ipairs(events) do
		self.ComponentAdded:Fire(event.clone, event.name, event.config)
	end
end


function ComponentsManager:DestroyComponents(groups)
	local cloneProfiles = self:GetCloneProfilesFromGroups(groups)
	for _, cloneProfile in next, cloneProfiles do
		self:_removeClone(cloneProfile.clone)
	end
end


function ComponentsManager:AddComponent(instance, name, config, groups, synced)
	local profile = self:_getOrMakeCloneProfile(instance, synced, groups)
	if profile:HasComponent(name) then
		return
	end

	self._componentHolders[name]:AddComponent(instance, config, synced)
	profile:AddComponent(name)

	return profile
end


function ComponentsManager:RemoveComponent(instance, name)
	local profile = self:_getOrMakeCloneProfile(instance, false)
	if not profile:HasComponent(name) then
		return
	end

	self._componentHolders[name]:RemoveComponent(instance)
	profile:RemoveComponent(name)

	if not profile:HasAComponent() then
		self:_removeClone(instance)
	end

	return self._cloneProfiles[instance]
end


function ComponentsManager:HasComponent(instance, name)
	local profile = self:_getOrMakeCloneProfile(instance, false)
	return profile:HasComponent(name)
end


function ComponentsManager:AddToGroup(instance, groupName)
	local profile = self:GetCloneProfileOrError(instance)
	local oldGroupsHash = ComponentsUtils.shallowCopy(profile:GetGroupsHash())
	profile:AddGroup(groupName)
	
	local group = self:_getOrMakeGroup(groupName)
	group:Add(instance)

	if not profile.synced then
		ComponentsUtils.updateGroupValueObjects(instance, profile:GetGroupsHash(), oldGroupsHash)
	end
end


function ComponentsManager:RemoveFromGroup(instance, groupName)
	local profile = self:GetCloneProfileOrError(instance)
	local oldGroupsHash = ComponentsUtils.shallowCopy(profile:GetGroupsHash())
	profile:RemoveGroup(groupName)

	local group = self:GetGroup(groupName)
	if group == nil then return end

	group:Remove(instance)

	if not profile:IsInAGroup() then
		self:_removeClone(instance)
	elseif not profile.synced then
		ComponentsUtils.updateGroupValueObjects(instance, profile:GetGroupsHash(), oldGroupsHash)
	end
end


function ComponentsManager:IsInGroup(instance, groupName)
	local group = self:GetGroup(groupName)
	if group == nil then
		return false
	end

	return group:IsAdded(instance)
end


function ComponentsManager:GetCloneProfilesFromGroups(groups)
	local cloneProfilesHash = {}

	for groupName in next, groups do
		local group = self:GetGroup(groupName)
		if group == nil then continue end

		for _, cloneProfile in next, group:GetAdded() do
			cloneProfilesHash[cloneProfile] = true
		end
	end

	local cloneProfilesArray = {}
	local len = 0
	for cloneProfile in next, cloneProfilesHash do
		len += 1
		cloneProfilesArray[len] = cloneProfile
	end

	return cloneProfilesArray
end


--Aliases:
function ComponentsManager:SetState(instance, name, deltaState)
	self._componentHolders[name]:SetState(instance, deltaState)
end


function ComponentsManager:GetState(instance, name)
	return self._componentHolders[name]:GetState(instance)
end


function ComponentsManager:Subscribe(instance, name, stateName, handler)
	return self._componentHolders[name]:Subscribe(instance, stateName, handler)
end


function ComponentsManager:IsAdded(instance, name)
	return self._componentHolders[name]:IsAdded(instance)
end


function ComponentsManager:SetTime(time)
	self._time = time
end


function ComponentsManager:GetGroup(groupName)
	return self._groups[groupName]
end
--/Aliases


function ComponentsManager:GetCloneProfile(instance)
	return self._cloneProfiles[instance]
end


function ComponentsManager:GetCloneProfileOrError(instance)
	local profile = self:GetCloneProfile(instance)
	if profile == nil then
		error(NO_PROFILE_ERR:format(instance:GetFullName()))
	end

	return profile
end


function ComponentsManager:GetCloneProfileFromPrototype(instance)
	local clone = self._prototypeToClone[instance]
	if clone == nil then
		return nil
	end

	return self._cloneProfiles[clone]
end


function ComponentsManager:_removeInstanceFromTables(instance)
	local profile = self._cloneProfiles[instance]
	self._prototypeToClone[profile.prototype.instance] = nil
	self._cloneProfiles[instance] = nil

	for compName in next, profile:GetComponentsHash() do
		self:RemoveComponent(instance, compName)
	end

	for groupName in next, profile:GetGroupsHash() do
		local group = self:GetGroup(groupName)
		group:Remove(instance)
	end

	profile:Destruct()
end


function ComponentsManager:_getOrMakeGroup(groupName)
	local group = self:GetGroup(groupName)
	if group == nil then
		group = ComponentsGroup.new()
		self._groups[groupName] = group
	end

	return group
end


function ComponentsManager:_newCloneProfile(clone, prototype, synced, groups)
	if self._cloneProfiles[clone] then
		error(("%q already has a clone profile!"):format(clone:GetFullName()))
	end

	if prototype == nil then
		groups = getGroups(clone, groups)
		prototype = makePrototype(clone:Clone(), clone.Parent, groups)
	elseif groups == nil then
		groups = ComponentsUtils.shallowMerge(prototype.groups, {Main = true})
	end

	local cloneProfile = CloneProfile.new(clone, prototype, synced)

	self._cloneProfiles[clone] = cloneProfile
	self._prototypeToClone[prototype.instance] = clone

	for groupName in next, groups do
		self:_getOrMakeGroup(groupName)
		self:AddToGroup(clone, groupName)
	end

	if synced then
		if not clone:FindFirstChild("ComponentsSyncronized") then
			local tag = Instance.new("BoolValue")
			tag.Name = "ComponentsSyncronized"
			tag.Archivable = false
			tag.Value = true
			tag.Parent = clone
		end

		cloneProfile:AddDestructFunction(ComponentsUtils.subscribeStateAnd(
			ComponentsUtils.getOrMakeStateFolder(clone), function(compName, stateName, value)
				if not self:HasComponent(clone, compName) then return end
				-- print("Setting state ", compName, stateName, value)
				self:SetState(clone, compName, {[stateName] = value})
			end))

		cloneProfile:AddDestructFunction(ComponentsUtils.subscribeGroupsAnd(
			ComponentsUtils.getOrMakeGroupsFolder(clone), function(groupName, exists)
				if exists then
					print("Adding group", clone, groupName)
					self:AddToGroup(clone, groupName)
				else
					print("Removing group", clone, groupName)
					self:RemoveFromGroup(clone, groupName)
				end
		end))
	end

	return cloneProfile
end


function ComponentsManager:_removeClone(clone)
	self:_removeInstanceFromTables(clone)
	-- This should not affect replication (i.e instance != nil on remotes fired immediately after).
	clone.Parent = nil
end


function ComponentsManager:_getOrMakeCloneProfile(clone, synced, groups)
	return self._cloneProfiles[clone] or self:_newCloneProfile(clone, nil, synced, groups)
end

return ComponentsManager