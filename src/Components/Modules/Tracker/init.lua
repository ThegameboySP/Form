local Maid = require(script.Maid)
local Event = require(script.Event)
local fastSpawn = require(script.fastSpawn)

--[[
	TODO:
	- setting source or any wrappers clears the tracker and reinitializes itself, which leads to:
	- use :On so all extensions can know when it's time to be cleared
	- make it easy to define multiple "targets", like Added, Fired, etc. a class?
]]

local Tracker = {}
Tracker.__index = Tracker
Tracker.ClassName = "Tracker"
Tracker.TrackerName = "Tracker"
Tracker.Event = Event

local RETURN_TRUE = function() return true end
local RETURN = function(...) return ... end
local DEFAULT_ADD_WRAPPER = function(instance, _, callback)
	callback(instance)
end

local function shallowCopy(t)
	local nt = {}
	for key, value in next, t do
		nt[key] = value
	end

	return nt
end

-- t1 -> t2
local function mergeTable(t1, t2)
	local copy = shallowCopy(t2)
	for key, value in next, t1 do
		copy[key] = value
	end

	return copy
end

function Tracker.new()
	local self = setmetatable({
		Added = Event.new();
		Removed = Event.new();

		maid = Maid.new();

		_trackingHash = {};
		_trackingArray = {};
		_trackingArrayLen = 0;

		_instanceMap = RETURN; -- For hooks that provide additional utility parameters.
		_instanceToContext = {};
		_srcInstanceToInstances = {};

		_filter = RETURN_TRUE;
		_addWrapper = DEFAULT_ADD_WRAPPER;
		_source = nil;
	}, Tracker)

	self.maid:GiveTask(self.Added)
	self.maid:GiveTask(self.Removed)

	return self
end
Tracker.start = Tracker.new

-- TODO: make this compatible with context?
function Tracker.getAdded(source, ...)
	local self = source.start(...)
	local added = shallowCopy(self:GetAdded())
	self:Destroy()
	return added
end


-- Wrapped execution goes: bottom tracker -> topmost -> NOOP tracker
-- MUST run wrappedOrFunc BEFORE setting its trackers source, as it may set initial parameters.
-- TODO: test
function Tracker.wrapWith(source, a2, a3)
	local trackerName
	local wrappedOrFunc
	if type(a2) == "string" then
		trackerName = a2
		wrappedOrFunc = a3
	else
		trackerName = nil
		wrappedOrFunc = a2
	end

	local wrapped = setmetatable({}, {__index = source})
	wrapped.__index = wrapped

	local _type = type(wrappedOrFunc)
	if _type == "function" then
		function wrapped.start(...)
			local self = source.new()
			self.TrackerName = trackerName
			wrappedOrFunc(self, ...)
			self:SetSource(source.start())

			return self
		end
	elseif _type == "table" then
		-- Meant to be used with import chains.
		-- Start the bottom tracker in this chain as usual, but set its root NOOP tracker source to our source parameter.
		function wrapped.start(...)
			local rootSource = source.new()
			rootSource.TrackerName = trackerName
	
			local bottomTracker = wrappedOrFunc.start(...)
			bottomTracker:GetRoot():SetSource(rootSource)
			rootSource:SetSource(source.start())

			return bottomTracker
		end
	else
		error("Invalid type: " .. _type)
	end

	return wrapped
end


function Tracker:extend(constructor)
	local class = setmetatable({}, {__index = self})
	class.__index = class

	class.new = constructor
	class.start = constructor
	
	return class
end


-- TODO: test that all elements are removed from the tracker on destruction
function Tracker:Destroy()
	for _, instance in next, self._trackingArray do
		self:Remove(instance)
	end

	self.maid:DoCleaning()
	table.clear(self._trackingHash)
	table.clear(self._trackingArray)
	table.clear(self._instanceToContext)
	table.clear(self._srcInstanceToInstances)
end


function Tracker:WrapInstanceCallback(wrapper, callback)
	local maid = Maid.new()

	maid:GiveTask(self:OnAdded(function(instance)
		local instanceMaid = Maid.new()
		maid[instance] = instanceMaid
		wrapper(instance, instanceMaid, function(...)
			callback(instance, ...)
		end)
	end))

	maid:GiveTask(self.Removed:Connect(function(instance)
		maid[instance] = nil
	end))

	return maid
end


-- TODO: test?
function Tracker:GetAncestor(name)
	local src = self._source
	if src == nil then
		return nil
	end

	if src.TrackerName == name then
		return src
	end

	return src:GetAncestor(name)
end


function Tracker:GetRoot()
	local src = self._source
	return src and src:GetRoot() or self
end


function Tracker:Add(instance, context)
	if self._filter(instance) == false then return end
	context = context or {}
	
	-- Merge context even if we already have this instance.
	-- TODO: test
	local properInstance, newContext = self._instanceMap(instance, shallowCopy(context))
	local mergedContext = mergeTable(newContext, context)
	self._instanceToContext[instance] = mergedContext

	if self._trackingHash[instance] then return end

	self._trackingArrayLen += 1
	self._trackingArray[self._trackingArrayLen] = instance
	self._trackingHash[instance] = true

	self.Added:Fire(properInstance, mergedContext)
	return self
end


function Tracker:Remove(instance)
	if not self._trackingHash[instance] then return end
	self._trackingArrayLen -= 1
	table.remove(self._trackingArray, table.find(self._trackingArray, instance))
	self._trackingHash[instance] = nil

	-- Fire Removed before setting _instanceToContext to nil in case any listeners use :GetInstanceContext.
	local context = shallowCopy(self._instanceToContext[instance])
	local properInstance = self._instanceMap(instance, shallowCopy(context))
	self.Removed:Fire(properInstance, context)

	self._instanceToContext[instance] = nil
	return self
end


function Tracker:OnAdded(func)
	local con = self.Added:Connect(func)
	for _, added in next, self:GetAdded() do
		local context = self._instanceToContext[added]
		local properInstance = self._instanceMap(added, shallowCopy(context))
		fastSpawn(func, properInstance, context)
	end

	return con
end


function Tracker:GetAdded()
	return self._trackingArray
end


function Tracker:IsAdded(instance)
	return self._trackingHash[instance] ~= nil
end


function Tracker:SetFilter(filter)
	assert(self._source == nil, "Can't set filter after setting the source!")
	self._filter = filter
	return self
end


function Tracker:GetFilter()
	return self._filter
end


function Tracker:SetAddWrapper(wrapper)
	assert(self._source == nil, "Can't set added wrapper after setting source!")
	self._addWrapper = wrapper
	return self
end


function Tracker:SetRemovedWrapper(wrapper)
	assert(self._source == nil, "Can't set removed wrapper after setting source!")
	if wrapper == nil then
		self.maid.RemovedWrapper = nil
		return
	end
	self.maid.RemovedWrapper = self:WrapInstanceCallback(wrapper, function(instance, ...)
		self:Remove(instance, ...)
	end)
	return self
end


-- Used to map .Added instance and context. Also used to map .Removed properly.
function Tracker:SetInstanceMap(map)
	assert(self._source == nil, "Can't set added map after setting source!")
	self._instanceMap = map
end


function Tracker:GetInstanceContext(instance)
	local context = self._instanceToContext[instance]
	if context == nil then
		return nil
	end

	return shallowCopy(context)
end


function Tracker:GetSource()
	return self._source
end


-- Once you set this, you can't set parameters anymore so it's ensured you don't get into bad state.
function Tracker:SetSource(source)
	assert(self._source == nil, "Can't set source twice!")
	local typeOf = typeof(source)

	self._source = source
	if typeOf == "Instance" then
		self.maid._source = self:_addTarget(source)
	elseif typeOf == "table" then
		local sourceMaid = Maid.new()
		-- Given source tracker is viewed as being "owned" by this instance.
		sourceMaid:GiveTask(source)
		self.maid._source = sourceMaid

		source.Removed:Connect(function(instance)
			sourceMaid[instance] = nil

			local entry = self._srcInstanceToInstances[instance]
			if entry == nil then return end

			for subInstance in next, entry do
				self:Remove(subInstance)
			end
		end)

		source:OnAdded(function(instance, context)
			sourceMaid[instance] = self:_addTarget(instance, context)
		end)
	else
		error("Invalid type: " .. typeOf, 2)
	end
	return self
end


function Tracker:_addTarget(target, context)
	local instances = self._srcInstanceToInstances[target]
	if instances == nil then
		instances = {}
		self._srcInstanceToInstances[target] = instances
	end

	local maid = Maid.new()
	self._addWrapper(target, maid, function(instance, thisContext)
		instances[instance] = true

		if context and thisContext then
			self:Add(instance, mergeTable(thisContext, context))
		else
			self:Add(instance, context or thisContext)
		end
	end, context)

	return maid
end

return Tracker