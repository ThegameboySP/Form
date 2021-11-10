local BaseComponent = require(script.Parent.BaseComponent)

return {
	Serializers = {
		Instance = function(instance)
			return instance
		end;

		[BaseComponent] = function(comp, man)
			return {
				type = "_component";
				name = comp.ClassName;
				ref = man.Serializers:Serialize(comp.ref);
			}
		end;
	};

	Deserializers = {
		_component = function(data, man)
			if data.ref == nil then
				return false, "Ref does not exist on this machine. Class: " .. data.name or ""
			end

			if data.name == nil then
				return false, "Component somehow does not have a ClassName. Ref: " .. data.ref:GetFullName()
			end

			return true, man:GetComponent(data.ref, data.name)
		end;
	};

	Extractors = {
		_component = function(data)
			return data
		end
	}
}