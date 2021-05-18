local t = require(script.Parent.Parent.Modules.t)
local ComponentMode = require(script.Parent.Parent.Shared.ComponentMode)

return t.strictInterface({
	config = t.optional(t.table);
	mode = t.optional(t.valueOf(ComponentMode));
	isWeak = t.optional(t.boolean);
})