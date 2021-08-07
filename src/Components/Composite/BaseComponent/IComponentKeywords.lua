local t = require(script.Parent.Parent.Parent.Modules.t)
return t.interface({
	class = t.table;
	config = t.optional(t.table);
	target = t.optional(t.union(t.table, t.Instance));
	layers = t.optional(t.table);
})