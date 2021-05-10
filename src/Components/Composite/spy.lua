local NOOP = function() end

return function(tbl, func)
	func = func or NOOP
	tbl.Count = tbl.Count or 0
	tbl.Ret = {}
	tbl.Params = {}

	return function(...)
		local ret = {func(...)}
		tbl.Count += 1
		table.insert(tbl.Ret, ret)
		table.insert(tbl.Params, {...})

		return unpack(ret, 1, #ret)
	end
end