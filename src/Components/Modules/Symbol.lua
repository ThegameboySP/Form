local Symbol = {}

local nameToSymbol = {}
local symbolToName = {}
local MT = {__tostring = function(t)
	return "Symbol_" .. symbolToName[t]
end}

function Symbol.named(name)
	if nameToSymbol[name] == nil then
		local symbol = setmetatable({}, MT)
		nameToSymbol[name] = symbol
		symbolToName[symbol] = name
	end

	return nameToSymbol[name]
end

return Symbol