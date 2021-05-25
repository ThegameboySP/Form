local SignalMixin = require(script.Parent.Parent.Parent.Composite.SignalMixin)
local Group = require(script.Parent.Group)
local GroupsComponent = require(script.Parent.GroupsComponent)
local Symbol = require(script.Parent.Parent.Parent.Modules.Symbol)

local GroupsExtension = {}
GroupsExtension.__index = GroupsExtension

local ERROR = function(ref)
	error(("%s is not a registered reference!"):format(ref:GetFullName()))
end

function GroupsExtension.new(man)
	local self = SignalMixin.new(setmetatable({
		_man = man;
		_groups = {};
		_comps = {};
	}, GroupsExtension))

	man:RegisterComponent(GroupsComponent)
	man:On("RefAdded", function(ref)
		local comp = man:GetOrAddComponent(ref, GroupsComponent, {
			isWeak = true;
		})
		comp:SetState({Default = true})
		self._comps[ref] = comp

		comp.externalMaid:Add(comp:SubscribeAnd("", function(changedGroups)
			for name, value in pairs(changedGroups) do
				if value == true then
					self:_add(ref, name)
				else
					self:_remove(ref, name)
				end
			end
		end))
	end)

	man:On("RefRemoved", function(ref)
		for name in pairs(self._groups) do
			self:_remove(ref, name)
		end

		self._comps[ref]:Destroy()
		self._comps[ref] = nil
	end)

	man:On("ComponentAdded", function(comp)
		if comp.Groups then
			local groups = self._comps[comp.ref]
			groups.Layers:SetConfig(comp.BaseName, comp.Groups)
		end
	end)

	man:On("ComponentRemoved", function(comp)
		local groups = self._comps[comp.ref]
		if groups == nil then return end
		groups.Layers:Remove(comp.BaseName)
	end)

	return self
end

function GroupsExtension:_add(ref, name)
	if not self._comps[ref] then
		error(ERROR(ref))
	end

	local group = self:_getOrMakeGroup(name)
	if group:IsAdded(ref) then return end
	group:Add(ref)

	self:Fire("Added", ref, name)
end

function GroupsExtension:Add(ref, name)
	local comp = self._comps[ref] or ERROR(ref)
	comp.Layers:MergeState("Manual", {[name] = true})
	self:_add(ref, name)
end

function GroupsExtension:Remove(ref, name)
	local comp = self._comps[ref] or ERROR(ref)
	comp.Layers:MergeState("Manual", {[name] = Symbol.named("null")})
	self:_remove(ref, name)
end

function GroupsExtension:_remove(ref, name)
	if not self._comps[ref] then
		error(ERROR(ref))
	end

	local group = self._groups[name]
	if not group:IsAdded(ref) then return end
	group:Remove(ref)

	self:Fire("Removed", ref, name)
end

function GroupsExtension:Get(ref)
	local comp = self._comps[ref]

	if comp then
		local array = {}
		for name in pairs(comp.state) do
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