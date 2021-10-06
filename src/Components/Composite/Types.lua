local t = require(script.Parent.Parent.Modules.t)
local NetworkMode = require(script.Parent.Parent.Shared.NetworkMode)

return {
	ComponentDefinition = t.interface({
		CheckRef = t.optional(t.callback);
		RequiredEmbedded = t.optional(t.table);
		Defaults = t.optional(t.table);
		Schema = t.optional(t.callback);

		NetworkMode = t.optional(t.valueOf(NetworkMode));
		ClassName = t.string;

		-- For component-specific initalization and accessing external things.
		Init = t.optional(t.callback);
		-- For firing events and setting into motion internal processes.
		Start = t.optional(t.callback);
	})
}