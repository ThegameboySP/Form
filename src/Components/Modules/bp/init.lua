local Maid = require(script.Parent.Maid)
local Tracker = require(script.Parent.Tracker)
local runCoroutineOrWarn = require(script.Parent.Parent.Composite.runCoroutineOrWarn)

local bp = {}
bp.__index = bp
local PASS = function() return true end

bp.childrenFilter = function(filter)
	return function(instance, maid, add, remove)
		local function onChildAdded(child)
			if filter(child) then
				add(child)
			else
				remove(child)
			end
		end

		maid:Add(instance.ChildAdded:Connect(onChildAdded))
		maid:Add(instance.ChildRemoved:Connect(remove))
		for _, child in pairs(instance:GetChildren()) do
			onChildAdded(child)
		end
	end
end

bp.children = bp.childrenFilter(PASS)

bp.filter = function(filter)
	return function(instance, _, add, remove)
		if filter(instance) then
			add(instance)
		else
			remove(instance)
		end
	end
end

bp.childNamed = function(name)
	return bp.childrenFilter(function(child)
		return child.Name == name
	end)
end

bp.attribute = function(attr, value)
	return function(instance, maid, add, remove)
		local function onChanged()
			if instance:GetAttribute(attr) == value then
				add(instance)
			else
				remove(instance)
			end
		end

		maid:Add(instance:GetAttributeChangedSignal(attr):Connect(onChanged))
		onChanged()
	end
end

bp.componentFilter = function(filter)
	return function(comp, maid, add, remove)
		local filterAndAdd = function(subComp)
			if not filter(subComp) then return end
			add(subComp)
		end
		maid:Add(comp:On("ComponentAdded", filterAndAdd))
		maid:Add(comp:On("ComponentRemoved", remove))

		for _, subComp in pairs(comp.added) do
			filterAndAdd(subComp)
		end
	end
end

bp.component = bp.componentFilter(PASS)
bp.componentOf = function(class)
	return bp.componentFilter(function(comp)
		return comp:GetClass() == class
	end)
end

local function nest(schema, tracker, dict, source)
	for getter, value in pairs(dict) do
		local subTracker = Tracker.new()

		subTracker:SetAddWrapper(function(instance, maid, add)
			getter(instance, maid, add, function(removing)
				subTracker:Remove(removing)
			end)
		end)
		subTracker:SetInstanceMap(function(i)
			return i, {instance = i, source = source}
		end)
		subTracker:SetSource(tracker)

		subTracker:OnAdded(function(sub, context)
			local t = type(value)

			if t == "function" then
				local r1, r2 = value(context)

				if r1 == false and r2 then
					nest(schema, Tracker.new():Add(sub):SetSource(subTracker), r2, context)
				else
					local destTracker = Tracker.new()
					destTracker:SetInstanceMap(function(_, c)
						return value(c), c
					end)
					destTracker:SetSource(subTracker)
					destTracker:OnAdded(function(ret)
						schema._matched[ret] = true
						schema:_fireMatched(ret)
					end)
					destTracker.Removed:Connect(function(ret)
						schema._matched[ret] = nil
					end)
				end
			elseif t == "table" then
				nest(schema, Tracker.new():Add(sub):SetSource(subTracker), value, context)
			else
				error("Invalid type: " .. t)
			end
		end)
	end
end

function bp.new(instance, dict)
	local self = bp._new()
	local context = {root = instance}
	local tracker = Tracker.new():Add(instance, context)
	nest(self, tracker, dict, context)

	return self
end

function bp._new()
	return setmetatable({
		_maid = Maid.new();
		_matched = {};
		_listeners = {};
	}, bp)
end

function bp:Destroy()
	self._maid:DoCleaning()
	table.clear(self._listeners)
	table.clear(self._matched)
end

function bp:OnMatched(handler)
	for i in pairs(self._matched) do
		handler(i)
	end
	table.insert(self._listeners, handler)

	return function()
		local index = table.find(self._listeners, handler)
		if index == nil then return end
		table.remove(self._listeners, index) 
	end
end

function bp:_fireMatched(...)
	for _, listener in ipairs(self._listeners) do
		runCoroutineOrWarn("Listener errored: %s\nTraceback: %s", listener, ...)
	end
end

function bp:GetMatched()
	local array = {}
	for matched in pairs(self._matched) do
		table.insert(array, matched)
	end

	return array
end

return bp