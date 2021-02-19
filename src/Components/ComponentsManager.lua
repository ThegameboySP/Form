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

function ComponentsManager.new()
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

	table.clear(self._cloneProfiles)
	table.clear(self._prototypes)
	table.clear(self._prototypeToClone)
end


function ComponentsManager:Init(root)
	local tags = {}
	for tag in next, self._srcs do
		table.insert(tags, tag)
	end
	local prototypes = self.generatePrototypesFromRoot(root, tags)

	for instance, prototype in next, prototypes do
		-- Check if it's a local clone, as otherwise we may screw up replication or other managers.
		if self:getCloneProfile(instance) then continue end
		if self._prototypes[instance] then continue end

		CollectionService:AddTag(instance, "Prototype")
		self._prototypes[instance] = prototype
		instance.Parent = nil

		if CollectionService:HasTag(instance, "ComponentsSyncronized") then
			self:_newCloneProfile(instance, prototype, true, prototype.groups)
		else
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
	assert(self._srcs[name] == nil, "Already registered component!")
	assert(RESERVED_COMPONENT_NAMES[name] == nil, "Name is reserved!")

	self._srcs[name] = src

	local holder = Components.new(self, src, name)
	self._componentHolders[name] = holder

	holder.ComponentAdded:Connect(function(clone, props)
		self.ComponentAdded:Fire(clone, name, props, self:getCloneProfile(clone).prototype.groups)
	end)

	holder.ComponentRemoved:Connect(function(clone)
		self.ComponentRemoved:Fire(clone, name)
	end)
end


function ComponentsManager:Reload(root)
	self:Destruct()

	assert(next(self._cloneProfiles) == nil, NOT_DESTRUCTED_ERR)
	assert(next(self._prototypes) == nil, NOT_DESTRUCTED_ERR)
	assert(next(self._prototypeToClone) == nil, NOT_DESTRUCTED_ERR)

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

		local props = self._componentHolders[name]:InitComponent(clone, nil)
		cloneProfile:AddComponent(name)
		table.insert(events, {clone = clone, name = name, props = props})
	end
	
	for _, newComponent in ipairs(newComponents) do
		local cloneProfile = newComponent.cloneProfile
		local clone = cloneProfile.clone
		local name = newComponent.componentName

		self._componentHolders[name]:RunComponentMain(clone)
	end

	for _, event in ipairs(events) do
		self.ComponentAdded:Fire(event.clone, event.name, event.props)
	end
end


function ComponentsManager:DestroyComponents(groups)
	local cloneProfiles = self:GetCloneProfilesFromGroups(groups)
	for _, cloneProfile in next, cloneProfiles do
		self:_removeClone(cloneProfile.clone)
	end
end


function ComponentsManager:AddComponent(instance, name, props, groups, sync)
	local profile = self:_getOrMakeCloneProfile(instance, sync, groups)
	if profile:HasComponent(name) then
		return
	end

	self._componentHolders[name]:AddComponent(instance, props)
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


function ComponentsManager:AddToGroup(instance, groupName)
	local profile = self:getCloneProfileOrError(instance)
	local oldGroupsHash = ComponentsUtils.shallowCopy(profile:GetGroupsHash())
	profile:AddGroup(groupName)
	
	local group = self:_getOrMakeGroup(groupName)
	group:Add(instance)

	ComponentsUtils.updateGroupValueObjects(instance, profile:GetGroupsHash(), oldGroupsHash)
end


function ComponentsManager:RemoveFromGroup(instance, groupName)
	local profile = self:getCloneProfileOrError(instance)
	local oldGroupsHash = ComponentsUtils.shallowCopy(profile:GetGroupsHash())
	profile:RemoveGroup(groupName)

	local group = self:GetGroup(groupName)
	if group == nil then return end

	group:Remove(instance)

	if not profile:IsInAGroup() then
		self:_removeClone(instance)
	else
		ComponentsUtils.updateGroupValueObjects(instance, profile:GetGroupsHash(), oldGroupsHash)
	end
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


function ComponentsManager:Subscribe(instance, name, stateName, handler)
	return self._componentHolders[name]:Subscribe(instance, stateName, handler)
end


function ComponentsManager:SetTime(time)
	self._time = time
end


function ComponentsManager:GetGroup(groupName)
	return self._groups[groupName]
end
--/Aliases


function ComponentsManager:getCloneProfile(instance)
	return self._cloneProfiles[instance]
end


function ComponentsManager:getCloneProfileOrError(instance)
	local profile = self:getCloneProfile(instance)
	if profile == nil then
		error(NO_PROFILE_ERR:format(instance:GetFullName()))
	end

	return profile
end


function ComponentsManager:getCloneProfileFromPrototype(instance)
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