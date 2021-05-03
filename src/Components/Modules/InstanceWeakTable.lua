local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local InstanceWeakTable = {}
InstanceWeakTable.__index = InstanceWeakTable

local WEAK_KEY = {__mode = "k"}

function InstanceWeakTable.new()
	local self = setmetatable({
		_tag = "WeakTable" .. HttpService:GenerateGUID(true);
		_weak = setmetatable({}, WEAK_KEY);
		_strong = {};
	}, InstanceWeakTable)
	
	self._addedCon = CollectionService:GetInstanceAddedSignal(self._tag):Connect(function(i)
		self._weak[i] = self._weak[i] or true
		self._strong[i] = true
	end)

	self._removedCon = CollectionService:GetInstanceRemovedSignal(self._tag):Connect(function(i)
		self._strong[i] = nil
	end)

	return self
end


function InstanceWeakTable:Destroy()
	self._addedCon:Disconnect()
	self._removedCon:Disconnect()

	for _, i in pairs(CollectionService:GetTagged(self._tag)) do
		CollectionService:RemoveTag(i, self._tag)
	end
end


function InstanceWeakTable:Add(instance, value)
	assert(typeof(instance) == "Instance")
	if value == nil then
		value = true
	end

	self._weak[instance] = value
	self._strong[instance] = true
	CollectionService:AddTag(instance, self._tag)
end


function InstanceWeakTable:Remove(instance)
	assert(typeof(instance) == "Instance")
	self._weak[instance] = nil
	self._strong[instance] = nil
	CollectionService:RemoveTag(instance, self._tag)
end


function InstanceWeakTable:IsAdded(instance)
	return self._weak[instance] ~= nil
end


function InstanceWeakTable:Get(instance)
	return self._weak[instance]
end


function InstanceWeakTable:GetAdded()
	local array = {}
	for i in pairs(self._weak) do
		table.insert(array, i)
	end

	return array
end

return InstanceWeakTable