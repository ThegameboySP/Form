local ComponentsUtils = require(script.Parent.Parent.Parent.Shared.ComponentsUtils)

local Ops = {}
--[[
	Rule #1: Operations must ALWAYS copy their injected tables.
	This may seem wasteful, but otherwise .Layers would mutate them during every merge.
	This means ops get to choose the most performant way to copy.

	Rule #2: Must ALWAYS copy table operands. Like the previous rule, for mutation safety.
]]

local op = function(def, func)
	return function(n)
		return function(c)
			return func(c or def, n)
		end
	end
end
Ops.add = op(0, function(c, n) return c + n end)
Ops.sub = op(0, function(c, n) return c - n end)
Ops.mul = op(1, function(c, n) return c * n end)
Ops.div = op(1, function(c, n) return c / n end)
Ops.mod = op(0, function(c, n) return c % n end)

local function always(op)
	return function(value, isTechnicalLayer)
		if isTechnicalLayer then
			return op(nil)
		end
		
		return op(value)
	end
end

function Ops.join(this)
	return function(with)
		local copy = with and {unpack(with)} or {}
		for _, value in ipairs(this) do
			table.insert(copy, value)
		end
		return copy
	end
end

function Ops.merge(this)
	return function(with)
		if with == nil then
			return ComponentsUtils.shallowCopy(this)
		end

		return ComponentsUtils.shallowMerge(this, with)
	end
end

return Ops