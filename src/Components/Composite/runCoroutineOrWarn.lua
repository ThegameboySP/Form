return function(format, func, ...)
	local co = coroutine.create(func)
	local ok, err = coroutine.resume(co, ...)

	if not ok then
		warn(format:format(err, debug.traceback(co)))
	end

	return ok
end