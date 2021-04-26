local Symbol = {}

local symbols = {}
function Symbol.named(name)
	symbols[name] = symbols[name] or {}
	
	return symbols[name]
end

return Symbol