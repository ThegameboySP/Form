return {
	lib = require(script.Composite.lib);
	Manager = require(script.Composite.Manager);

	BaseComponent = require(script.Composite.BaseComponent);
	ReferenceComponent = require(script.Composite.User.ReferenceComponent);
	UserUtils = require(script.Composite.User.UserUtils);
	FuncUtils = require(script.Composite.User.FuncUtils);

	Replication = require(script.Extensions.Replicator);
	Prototypes = require(script.Extensions.Prototypes);
	Groups = require(script.Extensions.Groups);

	TimeCycle = require(script.Modules.TimeCycle);
	Maid = require(script.Modules.Maid);
	t = require(script.Modules.t);
	bp = require(script.Modules.bp);
}