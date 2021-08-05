local t = require(script.Parent.Parent.Parent.Modules.t)
return t.strictInterface({
	config = t.optional(t.table);
	target = t.optional(t.union(t.table, t.Instance));
	layers = t.optional(t.table);
})