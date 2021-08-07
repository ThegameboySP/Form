local NULL = require(script.Parent.Parent.Parent.Modules.Symbol).named("null")

local Utils = {}

function Utils.stateDiff(new, old)
	local diff = {}

	for k, v in pairs(new) do
		local ov = old[k]
		if type(ov) == "table" and type(v) == "table" and ov ~= NULL and v ~= NULL then
			local subDiff = Utils.stateDiff(v, old[k])
			if next(subDiff) then
				diff[k] = subDiff
			end
		elseif ov ~= v then
			diff[k] = v
		end
	end

	for k in pairs(old) do
		if new[k] == nil then
			diff[k] = NULL
		end
	end

	return diff
end

function Utils.runStateFunctions(layer, union)
	for k, v in pairs(layer) do
		local lt = type(v)
		local uv = union[k]
		if lt == "table" and type(uv) == "table" and v ~= NULL and uv ~= NULL then
			Utils.runStateFunctions(v, uv)
		elseif lt == "function" then
			local r = v(uv)
			union[k] = r
		end
	end
end

function Utils.deepCopyState(state)
	local nt = {}
	for k, v in pairs(state) do
		if type(v) == "table" and v ~= NULL then
			nt[k] = Utils.deepCopyState(v)
		else
			nt[k] = v
		end
	end

	return nt
end

function Utils.deepMergeLayer(from, to)
	local new = Utils.deepCopyState(to)

	for k, v in pairs(from) do
		local ft = type(v)
		local tv = to[k]
		local tt = type(tv)

		if ft == "table" and v ~= NULL then
			local newTbl
			if tt == "table" and v ~= NULL then
				newTbl = tv
			else
				newTbl = {}
			end

			new[k] = Utils.deepMergeLayer(v, newTbl)
		else
			new[k] = v
		end
	end

	return new
end

function Utils.deepMergeState(from, to)
	for k, v in pairs(from) do
		local ft = type(v)
		local tv = to[k]
		local tt = type(tv)

		if v == NULL then
			to[k] = nil
		elseif ft == "table" then
			local toTbl
			if tt == "table" then
				toTbl = tv
			else
				toTbl = {}
				to[k] = toTbl
			end

			Utils.deepMergeState(v, toTbl)
		elseif ft ~= "function" then -- functions come at a later stage.
			to[k] = v
		end
	end
end

return Utils