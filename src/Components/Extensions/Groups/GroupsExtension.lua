local SignalMixin = require(script.Parent.Parent.Parent.Composite.SignalMixin)
local Group = require(script.Parent.Group)
local GroupsComponent = require(script.Parent.GroupsComponent)

local GroupsExtension = {}
GroupsExtension.__index = GroupsExtension

local ERROR = function(ref)
	error("%s is not a registered reference!"):format(ref:GetFullName())
end

function GroupsExtension.new(man)
	local self = SignalMixin.new(setmetatable({
		_man = man;
		_groups = {};
	}, GroupsExtension))

	man:RegisterComponent(GroupsComponent)
	man:On("RefAdded", function(ref)
		local profile = man:GetProfile(ref)
		profile.groups = {}

		self:Add(ref, "Default")
	end)

	man:On("RefRemoved", function(ref)
		for name in pairs(self._groups) do
			self:Remove(ref, name)
		end
	end)

	return self
end

function GroupsExtension:Add(ref, name)
	local profile = self._man:GetProfile(ref) or ERROR(ref)
	if profile.groups[name] then return end

	local group = self:_getOrMakeGroup(name)
	group:Add(ref)

	local keywords = {config = {[name] = true}, isWeak = true}
	local mirror = self._man:GetOrAddComponent(ref, GroupsComponent, keywords)
	profile.groups[name] = mirror

	self:Fire("Added", ref, name)
end

function GroupsExtension:Remove(ref, name)
	local profile = self._man:GetProfile(ref) or ERROR(ref)
	if not profile.groups[name] then return end

	local mirror = profile.groups[name]
	if not mirror.isDestroyed then
		profile.groups[name]:Destroy()
	end
	profile.groups[name] = nil

	local group = self._groups[name]
	group:Remove(ref)

	self:Fire("Removed", ref, name)
end

function GroupsExtension:Get(ref)
	local profile = self._man:GetProfile(ref)

	if profile then
		local array = {}
		for name in pairs(profile.groups) do
			table.insert(array, name)
		end
		return array
	end

	return {}
end

function GroupsExtension:Has(ref, name)
	local group = self._groups[name]
	if group == nil then
		return false
	end

	local profile = self._man:GetProfile(ref)
	if profile == nil then
		return false
	end

	return group:IsAdded(ref)
end

function GroupsExtension:GetInGroup(name)
	return self._groups[name] and self._groups[name]:GetAdded()
end

function GroupsExtension:_getOrMakeGroup(name)
	local group = self._groups[name]
	if group == nil then
		group = Group.new()
		self._groups[name] = group
	end

	return group
end

return SignalMixin.wrap(GroupsExtension)