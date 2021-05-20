local CollectionService = game:GetService("CollectionService")

local ComponentsUtils = {}

function ComponentsUtils.shallowCopy(tbl)
	local newTbl = {}
	for k, v in next, tbl do
		newTbl[k] = v
	end

	return newTbl
end


function ComponentsUtils.union(...)
	local to = {}

	for _, from in ipairs({...}) do
		for k, v in pairs(from) do
			to[k] = v
		end
	end

	return to
end


-- tbl1 -> tbl2
function ComponentsUtils.shallowMerge(tbl1, tbl2)
	local c = ComponentsUtils.shallowCopy(tbl2)
	for k, v in next, tbl1 do
		c[k] = v
	end
	
	return c
end


-- tbl1 -> tbl2
function ComponentsUtils.deepMerge(tbl1, tbl2)
	local c = ComponentsUtils.deepCopy(tbl2)

	for k, v in next, tbl1 do
		if type(v) == "table" then
			local ct = type(c[k]) == "table" and c[k] or {}
			c[k] = ComponentsUtils.deepMerge(v, ct)
		else
			c[k] = v
		end
	end

	return c
end


-- Assumes non-table keys.
function ComponentsUtils.deepCopy(t)
	local nt = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			nt[k] = ComponentsUtils.deepCopy(v)
		else
			nt[k] = v
		end
	end

	return nt
end


function ComponentsUtils.diff(new, old)
	local delta = {}

	for k, v in pairs(new) do
		local ov = old[k]

		if type(v) == "table" and type(ov) == "table" then
			local subDelta = ComponentsUtils.diff(v, ov)
			if next(subDelta) then
				delta[k] = subDelta
			end
		elseif v ~= ov then
			delta[k] = v
		end
	end

	return delta
end


function ComponentsUtils.shallowCompare(tbl1, tbl2)
	for k, v in next, tbl1 do
		if tbl2[k] ~= v then
			return false
		end
	end

	for k, v in next, tbl2 do
		if tbl1[k] ~= v then
			return false
		end
	end

	return true
end


function ComponentsUtils.deepCompare(tbl1, tbl2)
	for k, v in pairs(tbl1) do
		local t = type(v)
		local v2 = tbl2[k]
		local t2 = type(v2)

		local equals = true
		if t == "table" and t2 == "table" then
			equals = ComponentsUtils.deepCompare(v, v2)
		elseif v ~= v2 then
			equals = false
		end

		if equals == false then
			return false
		end
	end

	for k, v in pairs(tbl2) do
		local t = type(v)
		local v1 = tbl1[k]
		local t1 = type(v1)

		local equals = true
		if t == "table" and t1 == "table" then
			equals = ComponentsUtils.deepCompare(v, v1)
		elseif v ~= v1 then
			equals = false
		end

		if equals == false then
			return false
		end
	end

	return true
end


function ComponentsUtils.isInTable(tbl, value)
	for _, v in next, tbl do
		if v == value then
			return true
		end
	end

	return false
end


function ComponentsUtils.arrayToHash(array)
	local hash = {}
	for _, value in next, array do
		hash[value] = true
	end

	return hash
end


function ComponentsUtils.hashToArray(hash)
	local array = {}
	local len = 0
	for item in next, hash do
		len += 1
		array[len] = item
	end

	return array
end


function ComponentsUtils.indexTableOrError(name, tbl)
	return setmetatable(tbl, {__index = function(_, k)
		error(("%s is not a valid member of %q"):format(k, name), 2)
	end})
end

return ComponentsUtils