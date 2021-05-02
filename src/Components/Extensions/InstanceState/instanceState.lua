local StateInterfacer = require(script.StateInterfacer)
local ComponentsUtils = require(script.Parent.Parent.Parent.Shared.ComponentsUtils)

local function pathToState(stateTbl, path, value)
	local isLast = path:find("([^.]+)$") ~= nil
	local _, index, key = path:find("^([^.]+)%.?")

	if isLast then
		stateTbl[key] = value
	else
		stateTbl[key] = stateTbl[key] or {}
		pathToState(stateTbl[key], path:sub(index + 1, -1), value)
	end
end

-- This is compatible with non-managed units.
return function(view)
	view:On("ComponentAdded", function(ref, comp)
		local folder = StateInterfacer.getStateFolder(ref, comp.name)
		local delta = {}

		comp.maid:Add(StateInterfacer.subscribeComponentState(folder, function(path, value)
			local deltaState = pathToState({}, path, value)
			delta = ComponentsUtils.deepMerge(deltaState, delta)
		end, function()
			comp:SetState(delta)
		end))

		-- comp:ConnectEvent("StateChanged", function(deltaState)
		-- 	folder = StateInterfacer.getStateFolder(ref, comp.name)
		-- 	StateInterfacer.mergeStateValueObjects(folder, deltaState)
		-- end)
	end)
end