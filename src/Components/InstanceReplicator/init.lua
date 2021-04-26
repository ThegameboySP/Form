local StateInterfacer = require(script.StateInterfacer)
local ComponentsUtils = require(script.Parent.Parent.ComponentsUtils)
local Symbol = require(script.Parent.Parent.Modules.Symbol)

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

return function(man)
	man:On("ComponentAdded", function(comp)
		local folder = StateInterfacer.getStateFolder(comp.instance, comp.name)
		local delta = {}
		local flushFunc = makeFlush(comp, delta)

		comp.maid:Add(StateInterfacer.subscribeComponentState(folder, function(path, value)
			local deltaState = pathToState({}, path, value)
			ComponentsUtils.deepMerge(deltaState, delta)
		end, flushFunc))

		comp:ConnectEvent(Symbol.named("stateSet"), function(deltaState)
			if comp:IsSynced() then return end

			folder = StateInterfacer.getStateFolder(comp.instance, comp.name)
			StateInterfacer.mergeStateValueObjects(folder, deltaState)
		end)
	end)
end