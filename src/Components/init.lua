return {
	Manager = require(script.Composite.Manager);

	BaseComponent = require(script.Composite.BaseComponent);
	ReferenceComponent = require(script.Composite.User.ReferenceComponent);
	UserUtils = require(script.Composite.User.UserUtils);
	FuncUtils = require(script.Composite.User.FuncUtils);

	Replication = require(script.Extensions.Replicator);

	Maid = require(script.Modules.Maid);
	t = require(script.Modules.t);
}