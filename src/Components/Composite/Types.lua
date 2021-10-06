local t = require(script.Parent.Parent.Parent.Modules.t)
local NetworkMode = require(script.Parent.Parent.Parent.Shared.NetworkMode)

return {
	ComponentDefinition = t.interface({
		CheckRef = t.optional(t.callback);
		Schema = t.optional(t.callback);

		NetworkMode = t.valueOf(NetworkMode);
		ClassName = "BaseComponent";

		OnDestroy = t.optional(t.callback);
		-- For component-specific initalization and accessing external things.
		Init = t.optional(t.callback);
		-- For firing events and setting into motion internal processes.
		Main = t.optional(t.callback);
	})
}