return function(msg)
	task.spawn(error, debug.traceback(msg, 2))
end