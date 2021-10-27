local Constants = require(script.Form.Constants)

return {
	lib = require(script.Form.lib);
	Manager = require(script.Form.Manager);

	BaseComponent = require(script.Form.BaseComponent);
	withMaid = require(script.Form.withMaidTrait);
	Utils = require(script.Shared.ComponentsUtils);
	Serializers = require(script.Form.Serializers);

	-- Prototypes = require(script.Extensions.Prototypes);
	-- Groups = require(script.Extensions.Groups);
	Replication = require(script.Extensions.Replication);
	Remote = require(script.Extensions.Remote);
	Binding = require(script.Extensions.Binding);

	TimeCycle = require(script.Modules.TimeCycle);
	Maid = require(script.Modules.Maid);
	t = require(script.Modules.t);

	None = Constants.None;
}