local Symbol = {}

local nameToSymbol = {}
local symbolToName = {}

local __tostring = function(t)
	return "Symbol_" .. symbolToName[t]
end

--[[
	Why userdata's instead of tables? Two reasons:
	- When inspecting via breakpointing, __tostring's result will be
	respected.
	- Guarantees no items can be added to it, unlike a table.
]]
function Symbol.named(name)
	if nameToSymbol[name] == nil then
		local symbol = newproxy(true)
		getmetatable(symbol).__tostring = __tostring
		nameToSymbol[name] = symbol
		symbolToName[symbol] = name
	end

	return nameToSymbol[name]
end

function Symbol.new(name)
	local symbol = newproxy(true)
	local fullName = "New_Symbol_" .. name
	getmetatable(symbol).__tostring = function()
		return fullName
	end
	
	return symbol
end

return Symbol