local t = require(script.Parent.Parent.Parent.Modules.t)
return t.strictInterface({
	config = t.optional(t.table);
	state = t.optional(t.table);
	target = t.optional(t.union(t.table, t.instance));
	layers = t.optional(t.table);
})