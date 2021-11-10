local t = require(script.Parent.Parent.Modules.t)
local NetworkMode = require(script.Parent.Parent.Shared.NetworkMode)

return {
	ComponentDefinition = t.interface({
		ClassName = t.string;
		NetworkMode = t.optional(t.valueOf(NetworkMode));

		CheckRef = t.optional(t.callback);
		RequiredEmbedded = t.optional(t.table);
		Defaults = t.optional(t.table);
		Schema = t.optional(t.table);

		-- For component-specific initialization.
		OnInit = t.optional(t.callback);
		-- For firing events, accessing external things, and setting into motion internal processes.
		OnStart = t.optional(t.callback);
	})
}