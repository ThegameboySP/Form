local ComponentsUtils = require(script.Parent.Parent.Parent.Shared.ComponentsUtils)
local runCoroutineOrWarn = require(script.Parent.Parent.runCoroutineOrWarn)

local KeypathSubscriptions = {}
KeypathSubscriptions.__index = KeypathSubscriptions

local function deltaToPaths(delta, parentKey)
	parentKey = parentKey and (parentKey .. ".") or ""
	
	local paths = {}
	for key, value in pairs(delta) do
		local keyPath = parentKey .. key
		if type(value) == "table" then
			paths[keyPath] = value
			paths = ComponentsUtils.shallowMerge(deltaToPaths(value, keyPath), paths)
		else
			paths[keyPath] = value
		end
	end

	return paths
end


function KeypathSubscriptions.new()
	return setmetatable({
		_subscriptionsByPath = {};
		_firedPaths = {};
	}, KeypathSubscriptions)
end


function KeypathSubscriptions:Destroy()
	table.clear(self._subscriptionsByPath)
end


function KeypathSubscriptions:Subscribe(keyPath, handler)
	self._subscriptionsByPath[keyPath] = self._subscriptionsByPath[keyPath] or {}
	local listeners = self._subscriptionsByPath[keyPath]
	table.insert(listeners, handler)

	return function()
		local i = table.find(listeners, handler)
		if i == nil then return end
		table.remove(listeners, i)
	end
end


function KeypathSubscriptions:FireFromDelta(delta)
	local paths = deltaToPaths(delta)
	if next(paths) then
		paths[""] = delta
	end
	
	local pathToFired = {}
	for path in pairs(paths) do
		pathToFired[path] = self._firedPaths[path]
	end

	for path, value in pairs(paths) do
		local subscriptions = self._subscriptionsByPath[path]
		if subscriptions == nil then continue end
		-- Don't fire if the subscription was already fired from a previous coroutine in the loop.
		if self._firedPaths[path] ~= pathToFired[path] then continue end

		local format = ("Subscription at %q errored: %s"):format(path, "%s\nTrace: %s")
		for _, subscriber in ipairs(subscriptions) do
			self._firedPaths[path] = {}
			runCoroutineOrWarn(format, subscriber, value)
		end
	end
end

return KeypathSubscriptions