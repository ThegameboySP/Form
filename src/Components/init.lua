local Symbol = require(script.Modules.Symbol)

return {
	lib = require(script.Form.lib);
	Manager = require(script.Form.Manager);

	BaseComponent = require(script.Form.BaseComponent);
	MaidComponent = require(script.Form.MaidComponent);
	Utils = require(script.Shared.ComponentsUtils);

	-- Prototypes = require(script.Extensions.Prototypes);
	-- Groups = require(script.Extensions.Groups);
	Replication = require(script.Extensions.Replication);
	Remote = require(script.Extensions.Remote);
	Binding = require(script.Extensions.Binding);

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