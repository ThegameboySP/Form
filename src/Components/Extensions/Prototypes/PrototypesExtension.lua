local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ComponentsUtils = require(script.Parent.Parent.Parent.Shared.ComponentsUtils)
local t = require(script.Parent.Parent.Parent.Modules.t)
local Utils = require(script.Parent.Utils)

local PrototypesExtension = {}
PrototypesExtension.__index = PrototypesExtension

local IS_SERVER = RunService:IsServer()
local PASS = function() return true end
local PROTOTYPE_FILTER = function(instance)
	return not (IS_SERVER == false and CollectionService:HasTag(instance, "ServerComponent"))
end

function PrototypesExtension.new(man)
	return setmetatable({
		_man = man;
		_pInstanceToPrototypes = {};
		_prototypeToClone = {};
		_cloneProfiles = {};
	}, PrototypesExtension)
end

function PrototypesExtension:_initPrototypes(prototypes)
	local newPrototypes = {}
	local prototypesArray = {}

	for instance, prototype in pairs(prototypes) do
		if instance:GetAttribute("CompositeClone") then continue end
		if self:GetCloneProfile(instance) then continue end
		if self._pInstanceToPrototypes[instance] then continue end
		if not PROTOTYPE_FILTER(instance) then continue end

		local hasComponent = false
		for tag in pairs(prototype.hasTags) do
			local src = self._man.Classes[tag]
			local IInstance = src.getInterfaces(t).IInstance

			if IInstance then
				local ok, err = IInstance(instance)
				if not ok then
					warn(err)
					-- CollectionService:RemoveTag(instance, tag)
					continue
				end
			end

			local initInstance = src.initInstance
			if initInstance then
				initInstance(instance)
			end

			hasComponent = true
		end

		if not hasComponent then
			continue
		end
		
		self._pInstanceToPrototypes[instance] = prototype
		newPrototypes[instance] = prototype
		table.insert(prototypesArray, prototype)
	end

	for instance, prototype in pairs(newPrototypes) do
		prototype.ancestorPrototype = Utils.findFirstAncestorInDict(instance.Parent, newPrototypes)
	end

	for instance in pairs(newPrototypes) do
		instance.Parent = nil
	end

	return prototypesArray
end

function PrototypesExtension:_getTags()
	local tags = {}
	for tag in pairs(self._man.Classes) do
		table.insert(tags, tag)
	end

	return tags
end

-- Initializes all prototypes under this root (including the root), then sets their parents to nil for the time being.
function PrototypesExtension:InitFilter(root, filter, groups)
	local prototypes = Utils.generatePrototypesFromRoot(self:_getTags(), root, groups or {})
	local usingPrototypes = {}

	for instance, prototype in pairs(prototypes) do
		if not filter(prototype) then continue end
		usingPrototypes[instance] = prototype
	end
	
	return self:_initPrototypes(usingPrototypes)
end

function PrototypesExtension:Init(root, groups)
	local prototypes = Utils.generatePrototypesFromRoot(self:_getTags(), root, groups or {})
	return self:_initPrototypes(prototypes)
end

function PrototypesExtension:Stop(clonesArray)
	local clonesHash = clonesArray and ComponentsUtils.arrayToHash(clonesArray) or {}

	for clone, profile in pairs(self._cloneProfiles) do
		if clonesHash[profile.clone] == nil then continue end
		self:RemoveClone(clone)
	end
end

function PrototypesExtension:RemoveClone(clone)
	local profile = self._cloneProfiles[clone]
	assert(profile, "Not a clone!")
	
	self._man:RemoveRef(clone)
	self._cloneProfiles[clone] = nil
	self._prototypeToClone[profile.prototype.instance] = nil
	profile.prototype.cloneActive = false

	clone.Parent = nil
end

function PrototypesExtension:StopAll()
	return self:Stop(self:GetClones(PASS))
end

function PrototypesExtension:RestorePrototype(prototype)
	prototype.instance.Parent = prototype.parent
	self._pInstanceToPrototypes[prototype.instance] = nil
end

function PrototypesExtension:GetClones(filter)
	local clones = {}
	for _, prototype in pairs(self._pInstanceToPrototypes) do
		local clone = self._prototypeToClone[prototype.instance]
		if clone == nil then continue end
		if not filter(clone, prototype) then continue end

		table.insert(clones, clone)
	end

	return clones
end

function PrototypesExtension:GetPrototypes(filter)
	local prototypes = {}
	for _, prototype in pairs(self._pInstanceToPrototypes) do
		if not filter(prototype) then continue end

		table.insert(prototypes, prototype)
	end

	return prototypes
end

-- Gives all prototypes clone profiles (if not done so already) and merges components into internal data. Will
-- not re-run components from a previous call.
function PrototypesExtension:_runPrototypes(prototypes)
	local newComponents = {}

	for _, prototype in pairs(prototypes) do
		local clone = self._prototypeToClone[prototype.instance]
		
		-- No clone profile added; make one now.
		if clone == nil then
			local instance = prototype.instance

			-- If this is a Form clone, we can safely conclude another manager is at work. Continue.
			if instance:GetAttribute("CompositeClone") then
				continue
			else
				clone = instance:Clone()
				self:_newCloneProfile(clone, prototype)

				-- for group in pairs(prototype.groups) do
				-- 	self._man.Groups:Add(clone, group)
				-- end
			end
		end

		local profile = self._cloneProfiles[clone]
		local instance = prototype.instance

		for componentName in pairs(self._man.Classes) do
			if not CollectionService:HasTag(instance, componentName) then continue end
			if self._man:GetComponent(instance, componentName) then continue end

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

	local refs, classes, keywords = {}, {}, {}
	for _, new in ipairs(newComponents) do
		local clone = new.cloneProfile.clone
		local name = new.componentName
		local class = self._man.Classes[name]
		local config = Utils.getConfigFromInstance(clone, name)

		table.insert(refs, clone)
		table.insert(classes, class)
		table.insert(keywords, {config = config})
	end
	
	local comps = self._man:BulkAddComponent(refs, classes, keywords)
	return comps
end

function PrototypesExtension:RunFilter(filter)
	local prototypes = {}
	for _, prototype in pairs(self._pInstanceToPrototypes) do
		if not filter(prototype) then continue end
		table.insert(prototypes, prototype)
	end

	return self:_runPrototypes(prototypes)
end

function PrototypesExtension:RunAll()
	return self:_runPrototypes(self._pInstanceToPrototypes)
end

function PrototypesExtension:DestroyClonesFilter(filter)
	for clone, profile in pairs(self._cloneProfiles) do
		if not filter(clone, profile.prototype) then continue end
		self:RemoveClone(clone)
	end
end

-- Not intended to be used much by the end-user. Returns the internal representation of the prototype.
function PrototypesExtension:GetPrototype(instance)
	return self._pInstanceToPrototypes[instance]
end

function PrototypesExtension:GetPrototypeFromClone(clone)
	local profile = self._cloneProfiles[clone]
	if profile == nil then
		return nil
	end

	return profile.prototype
end

-- Not intended to be used much by the end-user. Returns the internal representation of the clone.
function PrototypesExtension:GetCloneProfile(instance)
	return self._cloneProfiles[instance]
end

function PrototypesExtension:GetCloneProfileOrError(instance)
	local profile = self:GetCloneProfile(instance)
	if profile == nil then
		error(("No clone profile for %q!"):format(instance:GetFullName()))
	end

	return profile
end

-- Not intended to be used much by the end-user. Returns the internal representation of the clone,
-- using the prototype instance in the query.
function PrototypesExtension:GetCloneProfileFromPrototype(instance)
	local clone = self._prototypeToClone[instance]
	if clone == nil then
		return nil
	end

	return self._cloneProfiles[clone]
end

-- TODO: support adding prototypes at runtime
function PrototypesExtension:_newCloneProfile(clone, prototype)
	assert(typeof(clone) == "Instance", "Expected 'Instance'")

	if self._cloneProfiles[clone] then
		error(("%q already has a clone profile!"):format(clone:GetFullName()))
	end

	local cloneProfile = {
		clone = clone;
		prototype = prototype or error("No prototype!");
	}

	prototype.cloneActive = true
	self._cloneProfiles[clone] = cloneProfile
	self._prototypeToClone[prototype.instance] = clone
	self._pInstanceToPrototypes[prototype.instance] = prototype

	clone:SetAttribute("CompositeClone", true)

	return cloneProfile
end

function PrototypesExtension:_getOrMakeCloneProfile(clone, synced, compMode, groups)
	return self._cloneProfiles[clone] or self:_newCloneProfile(clone, nil, synced, compMode, groups)
end

return PrototypesExtension