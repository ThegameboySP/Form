local Manager = require(script.Parent.Manager)
local ManagerCollection = require(script.Parent.ManagerCollection)

local lib = {}
lib.Managers = ManagerCollection.new()

local managers = {}
function lib:GetManager(name)
	local man = managers[name]
	
	if man == nil then
		man = Manager.new(name)
		managers[name] = man
		lib.Managers:Add(man)
	end

	return man
end

return lib