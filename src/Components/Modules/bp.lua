local Maid = require(script.Parent.Maid)
local Tracker = require(script.Parent.Tracker)
local InstanceWeakTable = require(script.Parent.InstanceWeakTable)

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
						schema._signal:Fire(ret)
						schema._matched:Add(ret)
					end)
					destTracker.Removed:Connect(function(ret)
						schema._matched:Remove(ret)
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
	local event = Instance.new("BindableEvent")
	return setmetatable({
		_maid = Maid.new();
		_signal = event;
		_matched = InstanceWeakTable.new();
		Matched = event.Event;
	}, bp)
end

function bp:Destroy()
	self._maid:DoCleaning()
	self._matched:Destroy()
	self._signal:Destroy()
end

function bp:OnMatched(handler)
	for _, i in pairs(self._matched:GetAdded()) do
		handler(i)
	end

	return self.Matched:Connect(handler)
end

function bp:GetMatched()
	return self._matched:GetAdded()
end

return bp