return function(warnParam, func, ...)
	local co = coroutine.create(func)
	local ok, err = coroutine.resume(co, ...)

	if not ok then
		if type(warnParam) == "function" then
			warn(warnParam(func, ...):format(err, debug.traceback(co)))
		else
			warn(warnParam:format(err, debug.traceback(co)))
		end
	end

	return ok
end