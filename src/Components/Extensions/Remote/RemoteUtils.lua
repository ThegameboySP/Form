local RemoteUtils = {}

function RemoteUtils.getOrMake(instance, name, class)
	local child = instance:FindFirstChild(name)
	if child then
		return child
	end

	local newChild = Instance.new(class)
	newChild.Name = name
	newChild.Parent = instance
	
	return newChild
end

local function make(comp, name, class)
	return RemoteUtils.getOrMake(
		comp.ref, comp.man.Name .. comp.ClassName .. name, class
	)
end

function RemoteUtils.makeEvent(comp, eventName)
	return make(comp, eventName, "RemoteEvent")
end

function RemoteUtils.makeFunction(comp, funcName)
	return make(comp, funcName, "RemoteFunction")
end

function RemoteUtils.getOrError(comp, name)
	return comp.ref:FindFirstChild(
		comp.man.Name .. comp.ClassName .. name
	)
end

local function waitForRemote(comp, name, callback)
	task.spawn(function()
		callback(comp.ref:WaitForChild(
			comp.man.Name .. comp.ClassName .. name
		))
	end)
end

function RemoteUtils.waitForEvent(comp, eventName, callback)
	waitForRemote(comp, eventName, callback)
end

function RemoteUtils.waitForFunction(comp, funcName, callback)
	return waitForRemote(comp, funcName, callback)
end

function RemoteUtils.initiallyDeferHandler(handler)
	local initial = true

	return function(...)
		if initial then
			initial = false

			local co = coroutine.running()
			task.defer(task.spawn, co)
			coroutine.yield()
		end

		handler(...)
	end
end

return RemoteUtils