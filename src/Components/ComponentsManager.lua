local CollectionService = game:GetService("CollectionService")

local Components = require(script.Parent.Components)
local ComponentsGroup = require(script.Parent.ComponentsGroup)
local ComponentsUtils = require(script.Parent.ComponentsUtils)
local CloneProfile = require(script.Parent.CloneProfile)
local Event = require(script.Parent.Modules.Event)
local t = require(script.Parent.Modules.t)

local ComponentsManager = {}
ComponentsManager.__index = ComponentsManager
ComponentsManager.NetworkMode = ComponentsUtils.indexTableOrError("NetworkMode", {
	SERVER = 1;
	CLIENT = 2;
	SERVER_CLIENT = 3;
	SHARED = 4;
})

local NOT_DESTRUCTED_ERR = "Behavior not fully destructed!"
local NO_PROFILE_ERR = "No clone profile for %q!"

local RESERVED_COMPONENT_NAMES = {
	Groups = true;
}
local RET_TRUE = function() return true end

local function getGroups(instance, groups)
	local instanceGroups = (ComponentsUtils.getGroups(instance) or groups)
	if next(instanceGroups) == nil then
		instanceGroups = {Main = true}
	end
	return instanceGroups
end

local function makePrototype(instance, parent, hasTags, groups)
	return {
		instance = instance;
		parent = parent;
		hasTags = hasTags;
		groups = groups;
		ancestorPrototype = nil;
	}
end

function ComponentsManager.new(filter)
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

		_filter = filter or RET_TRUE
	}, ComponentsManager)
end


function ComponentsManager.generatePrototypesFromRoot(tags, root)
	local prototypes = {}

	for instance, hasTags in next, ComponentsUtils.getTaggedInstancesFromRoot(tags, root) do
		if next(hasTags) == nil then continue end
		prototypes[instance] = makePrototype(instance, instance.Parent, hasTags, getGroups(instance, nil))
	end

	return prototypes
end


-- To be used when you aren't using Composite anymore on its area of influence, such as when switching maps.
-- Completely purges Composite side effects from the DataModel.
function ComponentsManager:Stop()
	for _, holder in next, self._componentHolders do
		holder:Clear()
	end

	for index, cloneProfile in next, self._cloneProfiles do
		cloneProfile:Destruct()
		self._cloneProfiles[index] = nil
	end

	for key, prototype in next, self._prototypes do
		prototype.instance.Parent = prototype.parent
		self._prototypes[key] = nil
	end

	table.clear(self._prototypeToClone)
	table.clear(self._groups)
end


function ComponentsManager:Init(root)
	local tags = {}
	for tag in next, self._srcs do
		table.insert(tags, tag)
	end
	local prototypes = self.generatePrototypesFromRoot(tags, root)

	local newPrototypes = {}
	for instance, prototype in next, prototypes do
		-- Check if it's a local clone, as otherwise we may screw up replication or other managers.
		if self:GetCloneProfile(instance) then continue end
		if self._prototypes[instance] then continue end

		local hasAComponent = false
		for tag in next, prototype.hasTags do
			if not self._filter(instance, tag) then continue end

			local src = self._srcs[tag]
			local IInstance = src.getInterfaces(t).IInstance
			if IInstance then
				local ok, err = IInstance(instance)
				if not ok then
					warn(err)
					CollectionService:RemoveTag(instance, tag)
					continue
				end
			end

			local initInstance = src.initInstance
			if initInstance then
				local shouldContinue = initInstance(instance)
				if shouldContinue == false then
					continue
				end
			end

			hasAComponent = true
		end

		if not hasAComponent then
			continue
		end
		
		CollectionService:AddTag(instance, "CompositeInstance")
		self._prototypes[instance] = prototype

		if instance:FindFirstChild("CompositeClone") then
			self:_newCloneProfile(instance, prototype, true, prototype.groups)
		else
			newPrototypes[instance] = prototype
		end
	end

	for instance, prototype in next, newPrototypes do
		local ancestor = ComponentsUtils.getAncestorCompositeInstance(instance)
		prototype.ancestorPrototype = ancestor and prototypes[ancestor] or nil
	end

	for instance in next, newPrototypes do
		instance.Parent = nil
	end

	for instance, prototype in next, newPrototypes do
		local clone = instance:Clone()
		self:_newCloneProfile(clone, prototype, false, prototype.groups)
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


function ComponentsManager:_runAndMergePrototypes(prototypes)
	local newComponents = {}

	for _, prototype in next, prototypes do
		local clone = self._prototypeToClone[prototype.instance]
		local profile = self._cloneProfiles[clone]
		local instance = prototype.instance

		for componentName in next, self._srcs do
			if not CollectionService:HasTag(instance, componentName) then continue end
			if profile:HasComponent(componentName) then continue end

			table.insert(newComponents, {
				cloneProfile = profile;
				componentName = componentName;
			})
		end
	end

	for _, newComponent in ipairs(newComponents) do
		local profile = newComponent.cloneProfile
		local clone = profile.clone

		if profile.prototype.ancestorPrototype then
			clone.Parent = self._prototypeToClone[profile.prototype.ancestorPrototype.instance]
		else
			clone.Parent = profile.prototype.parent
		end
	end

	local events = {}
	for _, newComponent in ipairs(newComponents) do
		local profile = newComponent.cloneProfile
		local clone = profile.clone
		local name = newComponent.componentName

		local config = self._componentHolders[name]:NewComponent(clone, nil, profile.synced)
		profile:AddComponent(name)
		table.insert(events, {clone = clone, name = name, config = config})
	end
	
	for _, newComponent in ipairs(newComponents) do
		local profile = newComponent.cloneProfile
		local clone = profile.clone
		local name = newComponent.componentName

		self._componentHolders[name]:PreInitComponent(clone)
	end

	for _, newComponent in ipairs(newComponents) do
		local profile = newComponent.cloneProfile
		local clone = profile.clone
		local name = newComponent.componentName

		self._componentHolders[name]:InitComponent(clone)
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


function ComponentsManager:RunAndMerge(allowedGroups)
	local prototypes = {}
	for _, cloneProfile in next, self:GetCloneProfilesFromGroups(allowedGroups) do
		table.insert(prototypes, cloneProfile.prototype)
	end

	return self:_runAndMergePrototypes(prototypes)
end


function ComponentsManager:RunAndMergeAll()
	return self:_runAndMergePrototypes(self._prototypes)
end


function ComponentsManager:RunAndMergeSynced()
	local prototypes = {}
	for prototype, clone in next, self._prototypeToClone do
		local profile = self._cloneProfiles[clone]
		if not profile.synced then continue end

		table.insert(prototypes, prototype)
	end

	return self:_runAndMergePrototypes(prototypes)
end


function ComponentsManager:DestroyComponentsInGroups(groups)
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


function ComponentsManager:GetComponent(instance, name)
	local holder = self._componentHolders[name]
	if not holder then return end
	return holder:GetComponent(instance)
end


function ComponentsManager:FireEvent(instance, compName, eventName, ...)
	self._componentHolders[compName]:FireEvent(instance, eventName, ...)
end


function ComponentsManager:ConnectEvent(instance, compName, eventName, handler)
	return self._componentHolders[compName]:ConnectEvent(instance, eventName, handler)
end


function ComponentsManager:FireInstanceEvent(instance, eventName, ...)
	local profile = self:GetCloneProfile(instance)
	if not profile then return end

	for compName in next, profile:GetComponentsHash() do
		self._componentHolders[compName]:FireEvent(instance, eventName, ...)
	end
end


function ComponentsManager:ConnectInstanceEvent(instance, eventName, handler)
	local profile = self:GetCloneProfileOrError(instance)

	local eventCons = {}
	local function onComponentAdded(name)
		eventCons[name] = self._componentHolders[name]:ConnectEvent(eventName, handler)
	end

	local addedCon = profile.ComponentAdded:Connect(onComponentAdded)
	for compName in next, profile:GetComponentsHash() do
		onComponentAdded(compName)
	end

	local removedCon = profile.ComponentRemoved:Connect(function(name)
		eventCons[name]:Disconnect()
		eventCons[name] = nil
	end)

	return function()
		addedCon:Disconnect()
		removedCon:Disconnect()

		for index, con in next, eventCons do
			con:Disconnect()
			eventCons[index] = nil
		end
	end
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

		for _, instance in next, group:GetAdded() do
			local cloneProfile = self._cloneProfiles[instance]
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


function ComponentsManager:DestroyCloneProfiles(profiles)
	assert(type(next(profiles)) == "number", "Expected array")

	for _, profile in ipairs(profiles) do
		self:_removeClone(profile.clone)
	end
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

	if prototype == nil and synced then
		groups = getGroups(clone, groups)
		prototype = makePrototype(clone, clone.Parent, {}, groups)
	elseif prototype == nil and not synced then
		groups = getGroups(clone, groups)
		prototype = makePrototype(clone:Clone(), clone.Parent, {}, groups)
	elseif prototype ~= nil and groups == nil then
		groups = ComponentsUtils.shallowMerge(prototype.groups, {Main = true})
	end

	local cloneProfile = CloneProfile.new(clone, prototype, synced)

	self._cloneProfiles[clone] = cloneProfile
	self._prototypeToClone[prototype.instance] = clone

	for groupName in next, groups do
		self:_getOrMakeGroup(groupName)
		self:AddToGroup(clone, groupName)
	end

	if not clone:FindFirstChild("CompositeClone") then
		local tag = Instance.new("BoolValue")
		tag.Name = "CompositeClone"
		tag.Archivable = false
		tag.Value = true
		tag.Parent = clone
	end

	if synced then
		cloneProfile:AddDestructFunction(ComponentsUtils.subscribeStateAnd(
			ComponentsUtils.getOrMakeStateFolder(clone), function(compName, stateName, value)
				if not self:HasComponent(clone, compName) then return end
				-- print("Setting state ", compName, stateName, value)
				self:SetState(clone, compName, {[stateName] = value})
			end))

		cloneProfile:AddDestructFunction(ComponentsUtils.subscribeGroupsAnd(
			ComponentsUtils.getOrMakeGroupsFolder(clone), function(groupName, exists)
				if exists then
					-- print("Adding group", clone, groupName)
					self:AddToGroup(clone, groupName)
				else
					-- print("Removing group", clone, groupName)
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