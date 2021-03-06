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
	SERVER = "Server";
	CLIENT = "Client";
	SERVER_CLIENT = "ServerClient";
	SHARED = "Shared";
})

local ComponentMode = ComponentsUtils.indexTableOrError("ComponentMode", {
	-- Get an instance prototype and clone on :RunAndMerge. Once all components are gone, remove the clone.
	RESPAWN = "Respawn";
	-- Get no instance prototype. Only use an instance. Once all components are gone, remove the instance.
	NO_RESPAWN = "NoRespawn";
	-- Get no instance prototype. Only use an instance. Once all components are gone, leave the instance.
	OVERLAY = "Overlay";
})
ComponentsManager.ComponentMode = ComponentMode

local NOT_DESTRUCTED_ERR = "Behavior not fully destructed!"
local NO_PROFILE_ERR = "No clone profile for %q!"
local REMOVE_TAG_PREFIX = "CompositeRemove_"

local RET_TRUE = function() return true end
local IS_SERVER = game:GetService("RunService"):IsServer()
local EMPTY_TABLE = {}

local function getGroups(instance, groups)
	local instanceGroups = (ComponentsUtils.getGroups(instance) or groups)
	if next(instanceGroups) == nil then
		instanceGroups = {Main = true}
	end

	return instanceGroups
end

local function makePrototype(instance, parent, compMode, hasTags, groups)
	return {
		instance = instance;
		parent = parent;
		compMode = compMode;
		hasTags = hasTags;
		groups = groups;
		ancestorPrototype = nil;
	}
end

function ComponentsManager.generatePrototypesFromRoot(tags, root, compMode)
	local prototypes = {}

	for instance, hasTags in next, ComponentsUtils.getTaggedInstancesFromRoot(tags, root) do
		if next(hasTags) == nil then continue end
		prototypes[instance] = makePrototype(instance, instance.Parent,
			instance:GetAttribute("ComponentMode") or compMode, hasTags, getGroups(instance, nil)
		)
	end

	return prototypes
end


function ComponentsManager.new(filter)
	return setmetatable({
		ComponentAdded = Event.new();
		ComponentRemoved = Event.new();
		CloneRemoved = Event.new();

		_srcs = {};
		_componentHolders = {};

		_timestamp = os.clock();
		_cloneProfiles = {};
		_pInstanceToPrototypes = {};
		_prototypeToClone = {};
		_groups = {};
		_unsafeConfigToOldParent = {};

		_filter = filter or RET_TRUE
	}, ComponentsManager)
end


-- To be used when you aren't using Composite anymore on its area of influence, such as when switching maps.
-- Completely purges Composite side effects from the DataModel.
function ComponentsManager:Stop()
	for instance, oldParent in next, self._unsafeConfigToOldParent do
		instance.Parent = oldParent
	end
	table.clear(self._unsafeConfigToOldParent)

	for instance, profile in next, self._cloneProfiles do
		for compName in next, profile:GetComponentsHash() do
			self:RemoveComponent(instance, compName)
		end
	end

	for index, cloneProfile in next, self._cloneProfiles do
		cloneProfile:Destruct()
		self._cloneProfiles[index] = nil
	end

	for key, prototype in next, self._pInstanceToPrototypes do
		prototype.instance.Parent = prototype.parent
		self._pInstanceToPrototypes[key] = nil
	end

	table.clear(self._prototypeToClone)
	table.clear(self._groups)
end


-- Initializes all prototypes under this root (including the root), then sets their parents to nil for the time being.
function ComponentsManager:Init(root)
	local tags = {}
	for tag in next, self._srcs do
		table.insert(tags, tag)
	end
	local prototypes = self.generatePrototypesFromRoot(tags, root, ComponentMode.RESPAWN)

	local newPrototypes = {}
	local prototypesArray = {}
	for instance, prototype in next, prototypes do
		-- Check if it's a local clone, as otherwise we may screw up replication or other managers.
		if self:GetCloneProfile(instance) then continue end
		if self._pInstanceToPrototypes[instance] then continue end

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
		
		instance:SetAttribute("CompositePrototype", true)
		self._pInstanceToPrototypes[instance] = prototype
		newPrototypes[instance] = prototype
		table.insert(prototypesArray, prototype)

		for groupName in next, prototype.groups do
			local group = self:_getOrMakeGroup(groupName)
			group:Add(prototype)
		end
	end

	for instance, prototype in next, newPrototypes do
		local ancestor = ComponentsUtils.getAncestorInstanceAttributeTag(instance.Parent, "CompositePrototype")
		prototype.ancestorPrototype = ancestor and prototypes[ancestor] or nil
	end

	for instance, prototype in next, newPrototypes do
		instance:SetAttribute("CompositePrototype", nil)

		-- Don't set parent to nil if this is a synced instance.
		if instance:GetAttribute("CompositeClone") then continue end
		if prototype.compMode == ComponentMode.OVERLAY then continue end
		instance.Parent = nil
	end

	return prototypesArray
end


function ComponentsManager:RegisterComponent(src)
	local name = src.ComponentName
	assert(type(name) == "string", "Expected 'string'")
	assert(type(src) == "table", "Expected 'table'")

	local baseName = ComponentsUtils.getBaseComponentName(name)
	assert(self._srcs[baseName] == nil, "Already registered component!")

	self._srcs[baseName] = src

	local holder = Components.new(self, src, baseName)
	self._componentHolders[baseName] = holder
end


-- Hard resets the manager.
function ComponentsManager:Reload(root)
	self:Stop()

	assert(next(self._cloneProfiles) == nil, NOT_DESTRUCTED_ERR)
	assert(next(self._pInstanceToPrototypes) == nil, NOT_DESTRUCTED_ERR)
	assert(next(self._prototypeToClone) == nil, NOT_DESTRUCTED_ERR)
	assert(next(self._groups) == nil, NOT_DESTRUCTED_ERR)

	self:Init(root)
end


-- Fixes any potentially dangerous configurations, such as a server only component with a modulescript.
function ComponentsManager:PrePass(root)
	if not IS_SERVER then return {} end

	local tags = {}
	for tag in next, self._srcs do
		table.insert(tags, tag)
	end

	local unsafeInstances = {}
	for instance, iTags in next, ComponentsUtils.getTaggedInstancesFromRoot(tags, root) do
		if not CollectionService:HasTag(instance, "OnlyServer") then continue end
		
		for tag in next, iTags do
			for _, value in next, ComponentsUtils.getConfigFromInstance(instance, tag) do
				if typeof(value) == "Instance" and value:IsA("ModuleScript") then
					local oldParent = value.Parent

					local pointer = Instance.new("ObjectValue")
					pointer.Value = value
					pointer.Name = value.Name
					pointer.Parent = value.Parent

					value.Parent = nil
					unsafeInstances[value] = oldParent
				end
			end
		end
	end

	return unsafeInstances
end


-- Gives all prototypes clone profiles (if not done so already) and merges components into internal data. Will
-- not re-run components from a previous call.
function ComponentsManager:_runAndMergePrototypes(prototypes)
	local newComponents = {}

	for _, prototype in next, prototypes do
		if prototype.compMode ~= ComponentMode.RESPAWN then continue end
		local clone = self._prototypeToClone[prototype.instance]
		
		-- No clone profile added; make one now.
		if clone == nil then
			local instance = prototype.instance

			-- If this is a Composite clone, we can safely conclude another manager is at work. Sync.
			if instance:GetAttribute("CompositeClone") then
				clone = instance
				self:_newCloneProfile(instance, prototype, true, ComponentMode.OVERLAY, prototype.groups)
			else
				clone = instance:Clone()
				self:_newCloneProfile(clone, prototype, false, ComponentMode.RESPAWN, prototype.groups)
			end
		end

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

		if CollectionService:HasTag(clone, "OnlyServer") and not profile.synced and IS_SERVER then
			local map = self:PrePass(clone)

			ComponentsUtils.shallowMerge(
				map,
				profile.unsafeConfigMap
			)

			ComponentsUtils.shallowMerge(
				map,
				self._unsafeConfigToOldParent
			)
		end

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
		table.insert(events, {clone = clone, name = name, config = config, profile = profile})
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
		local clone = event.clone
		local name = event.name
		local config = event.config

		if not event.profile.synced then
			ComponentsUtils.updateInstanceConfig(clone, name, config)
		end

		self.ComponentAdded:Fire(clone, name, config)
	end

	return newComponents
end


function ComponentsManager:RunAndMerge(allowedGroups)
	local prototypes = {}
	for _, prototype in next, self:_getPrototypesFromGroups(allowedGroups) do
		table.insert(prototypes, prototype)
	end

	return self:_runAndMergePrototypes(prototypes)
end


function ComponentsManager:RunAndMergeAll()
	return self:_runAndMergePrototypes(self._pInstanceToPrototypes)
end


function ComponentsManager:RunAndMergeSynced()
	local prototypes = {}
	for pInstance, prototype in next, self._pInstanceToPrototypes do
		if not pInstance:GetAttribute("CompositeClone") then continue end

		table.insert(prototypes, prototype)
	end

	return self:_runAndMergePrototypes(prototypes)
end


-- Destroys all clones that exist in any of the groups.
function ComponentsManager:DestroyClonesInGroups(groups)
	for _, prototype in next, self:_getPrototypesFromGroups(groups) do
		local clone = self._prototypeToClone[prototype.instance]
		if clone == nil then continue end

		self:RemoveClone(clone)
	end
end


-- Adds a component to the instance, if it doesn't have one already.
-- This is intended to be used independently of :RunAndMerge or :Init().

-- If you don't want the instance to eventually be cleaned up, use ComponentMode.OVERLAY.

-- WARNING: If no components were added to this instance before calling, the clean prototype
-- will be a clone of the instance. This is so it can maintain its identity.
function ComponentsManager:AddComponent(instance, name, config, keywords, groups)
	keywords = keywords or EMPTY_TABLE

	local synced = not not instance:GetAttribute("CompositeClone")
	local componentMode = keywords.componentMode or ComponentMode.NO_RESPAWN
	
	local profile = self:GetCloneProfile(instance)
	if profile and profile:HasComponent(name) then
		return
	end

	if not synced and not CollectionService:HasTag(instance, name) then
		CollectionService:AddTag(instance, name)
		instance:SetAttribute(REMOVE_TAG_PREFIX .. name, true)
		instance:SetAttribute("ComponentMode", componentMode)
	end

	if profile == nil then
		profile = self:_newCloneProfile(instance, nil, synced, componentMode, groups)
	end
	profile:AddComponent(name)

	if not synced and (keywords.onlyServer or CollectionService:HasTag(instance, "OnlyServer")) and IS_SERVER then
		if not CollectionService:HasTag(instance, "OnlyServer") then
			CollectionService:AddTag(instance, "OnlyServer")
			instance:SetAttribute(REMOVE_TAG_PREFIX .. "OnlyServer", true)
		end

		local map = self:PrePass(instance)
		ComponentsUtils.shallowMerge(
			map,
			profile.unsafeConfigMap
		)
		
		ComponentsUtils.shallowMerge(
			map,
			self._unsafeConfigToOldParent
		)
	end

	config = self._componentHolders[name]:AddComponent(instance, config, synced)

	if not profile.synced then
		ComponentsUtils.updateInstanceConfig(instance, name, config)
	end

	self.ComponentAdded:Fire(instance, name, config, groups)

	return profile
end


-- Removes a component of instance, if it has one.
-- This is intended to be used independently of :RunAndMerge or :Init().
function ComponentsManager:RemoveComponent(instance, name)
	local profile = self:GetCloneProfile(instance)

	if not profile or not profile:HasComponent(name) then
		return
	end

	self._componentHolders[name]:RemoveComponent(instance)
	profile:RemoveComponent(name)

	if not profile:HasAComponent() then
		self:RemoveClone(instance)
	end

	self.ComponentRemoved:Fire(instance, name)

	return self._cloneProfiles[instance]
end


function ComponentsManager:HasComponent(instance, name)
	local profile = self:GetCloneProfile(instance)
	if not profile then
		return false
	end

	return profile:HasComponent(name)
end


-- Not intended to be used that much. Instead, communicate mainly through state and events.
function ComponentsManager:GetComponent(instance, name)
	local holder = self._componentHolders[name]
	if not holder then return end
	return holder:GetComponent(instance)
end


-- Fires a component event for this instance, if it has the component.
function ComponentsManager:FireEvent(instance, compName, eventName, ...)
	self._componentHolders[compName]:FireEvent(instance, eventName, ...)
end


-- Connects to a component event for this instance. Errors if absent.
function ComponentsManager:ConnectEvent(instance, compName, eventName, handler)
	return self._componentHolders[compName]:ConnectEvent(instance, eventName, handler)
end


-- Fires an instance-wide event, firing all components it has.
function ComponentsManager:FireInstanceEvent(instance, eventName, ...)
	local profile = self:GetCloneProfile(instance)
	if not profile then return end

	for compName in next, profile:GetComponentsHash() do
		self._componentHolders[compName]:FireEvent(instance, eventName, ...)
	end
end


-- Connects to an instance-wide event. Doesn't error if no components are present at time of connection.
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
	group:Add(profile.prototype)

	if not profile.synced then
		ComponentsUtils.updateInstanceGroups(instance, profile:GetGroupsHash(), oldGroupsHash)
	end
end


function ComponentsManager:RemoveFromGroup(instance, groupName)
	local profile = self:GetCloneProfileOrError(instance)
	local oldGroupsHash = ComponentsUtils.shallowCopy(profile:GetGroupsHash())
	profile:RemoveGroup(groupName)

	local group = self:GetGroup(groupName)
	if group == nil then return end

	group:Remove(profile.prototype)

	if not profile:IsInAGroup() then
		self:RemoveClone(instance)
	elseif not profile.synced then
		ComponentsUtils.updateInstanceGroups(instance, profile:GetGroupsHash(), oldGroupsHash)
	end
end


function ComponentsManager:IsInGroup(instance, groupName)
	local group = self:GetGroup(groupName)
	if group == nil then
		return false
	end

	local profile = self:GetCloneProfile(instance)
	if profile == nil then
		return false
	end

	return group:IsAdded(profile.prototype)
end


function ComponentsManager:_getPrototypesFromGroups(groups)
	local cloneProfilesHash = {}

	for groupName in next, groups do
		local group = self:GetGroup(groupName)
		if group == nil then continue end

		for _, prototype in next, group:GetAdded() do
			cloneProfilesHash[prototype] = true
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

-- Sets and merges state for the instance's component. Errors no component is present.
function ComponentsManager:SetState(instance, name, deltaState)
	self._componentHolders[name]:SetState(instance, deltaState)
end


-- Gets mutatation-safe state for the instance's component. Errors if no component is present.
function ComponentsManager:GetState(instance, name)
	return self._componentHolders[name]:GetState(instance)
end


-- Subscribes to instance's component state name. Errors if no component is present.
function ComponentsManager:Subscribe(instance, name, stateName, handler)
	return self._componentHolders[name]:Subscribe(instance, stateName, handler)
end


function ComponentsManager:IsAdded(instance, name)
	return self._componentHolders[name]:IsAdded(instance)
end


-- Sets the time "base" that all time calculations use.
function ComponentsManager:SetTimestamp(timestamp)
	self._timestamp = timestamp
end


function ComponentsManager:GetTimestamp()
	return self._timestamp
end


-- Gets the internal time to be used for all components under this manager.
function ComponentsManager:GetTime()
	return os.clock() - self._timestamp
end


-- Sets a cycle by a name for a given instance component. Will simply change cycle length if already exists.
function ComponentsManager:SetCycle(instance, compName, cycleName, cycleLen)
	return self._componentHolders[compName]:SetCycle(instance, cycleName, cycleLen)
end


function ComponentsManager:GetCycle(instance, compName, cycleName)
	return self._componentHolders[compName]:GetCycle(instance, cycleName)
end


function ComponentsManager:GetGroup(groupName)
	return self._groups[groupName]
end
--/Aliases


-- Not intended to be used much by the end-user. Returns the internal representation of the prototype.
function ComponentsManager:GetPrototype(instance)
	return self._pInstanceToPrototypes[instance]
end


-- Not intended to be used much by the end-user. Returns the internal representation of the clone.
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


-- Not intended to be used much by the end-user. Returns the internal representation of the clone,
-- using the prototype instance in the query.
function ComponentsManager:GetCloneProfileFromPrototype(instance)
	local clone = self._prototypeToClone[instance]
	if clone == nil then
		return nil
	end

	return self._cloneProfiles[clone]
end


function ComponentsManager:_getOrMakeGroup(groupName)
	local group = self:GetGroup(groupName)
	if group == nil then
		group = ComponentsGroup.new()
		self._groups[groupName] = group
	end

	return group
end


function ComponentsManager:_newCloneProfile(clone, prototype, synced, compMode, groups)
	if self._cloneProfiles[clone] then
		error(("%q already has a clone profile!"):format(clone:GetFullName()))
	end
	
	assert(ComponentsUtils.isInTable(ComponentMode, compMode), "Invalid enum value!")
	assert(not synced or compMode == ComponentMode.NO_RESPAWN or compMode == ComponentMode.OVERLAY, "Bad args!")

	if prototype == nil and synced then
		groups = getGroups(clone, groups)
		prototype = makePrototype(clone, clone.Parent, compMode, {}, groups)
	elseif prototype == nil and not synced then
		groups = getGroups(clone, groups)
		prototype = makePrototype(clone:Clone(), clone.Parent, compMode, {}, groups)
	elseif prototype ~= nil and groups == nil then
		groups = ComponentsUtils.shallowMerge(prototype.groups, {Main = true})
	end

	local cloneProfile = CloneProfile.new(clone, prototype, synced)

	self._cloneProfiles[clone] = cloneProfile
	self._prototypeToClone[prototype.instance] = clone
	self._pInstanceToPrototypes[prototype.instance] = prototype

	for groupName in next, groups do
		self:AddToGroup(clone, groupName)
	end

	clone:SetAttribute("CompositeClone", true)

	if synced then
		cloneProfile:AddDestructFunction(ComponentsUtils.subscribeStateAnd(
			ComponentsUtils.getOrMakeStateFolder(clone), function(compName, stateName, value)
				if not self:HasComponent(clone, compName) then return end
				self:SetState(clone, compName, {[stateName] = value})
			end))

		cloneProfile:AddDestructFunction(ComponentsUtils.subscribeGroupsAnd(
			clone, function(groupName, exists)
				if exists then
					self:AddToGroup(clone, groupName)
				else
					self:RemoveFromGroup(clone, groupName)
				end
		end))
	end

	return cloneProfile
end


function ComponentsManager:_removeInstanceFromTables(instance)
	local profile = self._cloneProfiles[instance]

	for compName in next, profile:GetComponentsHash() do
		self:RemoveComponent(instance, compName)
	end

	for groupName in next, profile:GetGroupsHash() do
		local group = self:GetGroup(groupName)
		group:Remove(instance)
	end

	self._cloneProfiles[instance] = nil
	self._prototypeToClone[profile.prototype.instance] = nil

	-- Clear entire instance if it should not be respawned.
	if profile.prototype.compMode ~= ComponentMode.RESPAWN then
		self._pInstanceToPrototypes[profile.prototype.instance] = nil
	end

	profile:Destruct()
end


function ComponentsManager:RemoveClone(clone)
	local profile = self._cloneProfiles[clone]
	if not profile then return end
	local prototype = profile.prototype

	self:_removeInstanceFromTables(clone)
	
	for configInstance, oldParent in next, profile.unsafeConfigMap do
		self._unsafeConfigToOldParent[configInstance] = nil
		local sub = oldParent and oldParent:FindFirstChild(configInstance.Name)
		if sub and sub ~= configInstance then
			sub:Destroy()
		end
		
		configInstance.Parent = oldParent
	end

	if prototype.compMode ~= ComponentMode.OVERLAY then
		-- This should not affect replication (i.e instance != nil on remotes fired immediately after).
		clone.Parent = nil
	elseif not profile.synced then
		clone:SetAttribute("CompositeClone", nil)
		clone:SetAttribute("ComponentMode", nil)

		for _, child in next, clone:GetChildren() do
			if not CollectionService:HasTag(child, "CompositeCrap") then continue end
			child:Destroy()
		end

		for attrName in next, clone:GetAttributes() do
			if attrName:sub(1, #REMOVE_TAG_PREFIX) ~= REMOVE_TAG_PREFIX then continue end
			clone:SetAttribute(attrName, nil)
			CollectionService:RemoveTag(clone, attrName:sub(#REMOVE_TAG_PREFIX + 1))
		end

		ComponentsUtils.removeCompositeMutation(clone)
	end

	self.CloneRemoved:Fire(clone)
end


function ComponentsManager:_getOrMakeCloneProfile(clone, synced, compMode, groups)
	return self._cloneProfiles[clone] or self:_newCloneProfile(clone, nil, synced, compMode, groups)
end

return ComponentsManager