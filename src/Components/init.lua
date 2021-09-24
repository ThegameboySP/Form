local Symbol = require(script.Modules.Symbol)

return {
	lib = require(script.Composite.lib);
	Manager = require(script.Composite.Manager);

	BaseComponent = require(script.Composite.BaseComponent);
	UserUtils = require(script.Composite.User.UserUtils);
	FuncUtils = require(script.Composite.User.FuncUtils);

	Prototypes = require(script.Extensions.Prototypes);
	Groups = require(script.Extensions.Groups);

	TimeCycle = require(script.Modules.TimeCycle);
	Maid = require(script.Modules.Maid);
	t = require(script.Modules.t);

	None = Symbol.named("none");

	reducerKey = function(keys)
		return function(self, _, key)
			local reducer = keys[key]
			if reducer == nil then return end

			self.Data:Set(
				"final",
				key,
				reducer(self.Data:GetValues(key))
			)
		end;
	end;

	layerCallbacks = function(callbacksByLayer)
		return function(self, layerKey, key, value, oldValue)
			local callback = callbacksByLayer[layerKey]
			if callback == nil then return end

			callback(self, key, value, oldValue)
		end
	end;
}