local t = require(script.Parent.Parent.Modules.t)

return t.strictInterface({
	config = t.optional(t.table);
	layers = t.optional(t.table);
})