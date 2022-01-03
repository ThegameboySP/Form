local Ops = {}

local function wrap(transform)
	return {__transform = transform}
end
Ops.wrap = wrap

local op = function(def, func)
	return function(n)
		return wrap(function(c)
			return func(c or def, n)
		end)
	end
end

Ops.add = op(0, function(c, n) return c + n end)
Ops.sub = op(0, function(c, n) return c - n end)
Ops.mul = op(1, function(c, n) return c * n end)
Ops.div = op(1, function(c, n) return c / n end)
Ops.mod = op(0, function(c, n) return c % n end)

function Ops.join(this)
	return wrap(function(with)
		if with == nil then
			return this
		end

		for _, value in ipairs(this) do
			table.insert(with, value)
		end
		
		return with
	end)
end

function Ops.merge(this)
	return wrap(function(with)
		if with == nil then
			return this
		end

		for k, v in pairs(this) do
			with[k] = v
		end

		return with
	end)
end

return Ops