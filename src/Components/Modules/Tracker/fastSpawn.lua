return function(func, ...)
	assert(type(func) == "function")

	local co = coroutine.create(func)
	local ok, err = coroutine.resume(co, ...)

	if not ok then
		warn("Errored:", err, debug.traceback(co))
	end
end