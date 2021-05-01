local StateInterfacer = require(script.StateInterfacer)
local ComponentsUtils = require(script.Parent.Parent.Parent.ComponentsUtils)
local Symbol = require(script.Parent.Parent.Parent.Modules.Symbol)

local function makeFlush(comp, delta)
	comp:SetState(delta)
	table.clear(delta)
end

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
		local flushFunc = makeFlush(comp, delta)

		comp.maid:Add(StateInterfacer.subscribeComponentState(folder, function(path, value)
			local deltaState = pathToState({}, path, value)
			ComponentsUtils.deepMerge(deltaState, delta)
		end, flushFunc))

		comp:ConnectEvent(Symbol.named("stateSet"), function(deltaState)
			if comp:IsSynced() then return end

			folder = StateInterfacer.getStateFolder(ref, comp.name)
			StateInterfacer.mergeStateValueObjects(folder, deltaState)
		end)
	end)
end