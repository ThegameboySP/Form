local Utils = {}

local NetworkMode = require(script.Parent.Parent.Parent.Shared.NetworkMode)

function Utils.shouldReplicate(class)
	return class.NetworkMode == NetworkMode.ServerClient
	or class.NetworkMode == NetworkMode.Shared
	or class.NetworkMode == NetworkMode.Client
end

function Utils.path(ref, compName)
	return ref:GetFullName() .. "." .. compName
end

return Utils