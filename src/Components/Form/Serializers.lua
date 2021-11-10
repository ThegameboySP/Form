local BuiltinSerializers = require(script.Parent.BuiltinSerializers)
local ComponentsUtils = require(script.Parent.Parent.Shared.ComponentsUtils)

local FailMode = ComponentsUtils.indexTableOrError("FailMode", {
	Error = "Error";
	Silent = "Silent";
	Warn = "Warn";
})
local Serializers = {
	FailMode = FailMode;
}
Serializers.__index = Serializers

--[[
	Fully abstracts object sending/retrival across the network.
	Strategies can be overriden, especially for swapping out ref's dynamically.
]]

function Serializers.new(man)
	return setmetatable({
		man = man;
		_serializers = setmetatable({}, {__index = BuiltinSerializers.Serializers});
		_deserializers = setmetatable({}, {__index = BuiltinSerializers.Deserializers});
		_extractors = setmetatable({}, {__index = BuiltinSerializers.Extractors});
	}, Serializers)
end

function Serializers:Serialize(object)
	local serializer = self:FindSerializer(object)
		or error(("No serializer found for object: %s"):format(tostring(object)))

	local serialized = serializer(object, self.man)

	if
		serialized == nil
		or (type(serialized) == "table" and type(serialized.type) ~= "string")
	then
		error(("Could not serialize for component %s"):format(tostring(object)))
	end

	return serialized
end

function Serializers:Deserialize(serializedTarget, failMode)
	if type(serializedTarget) ~= "table" then
		return serializedTarget
	end

	if failMode == nil then
		failMode = FailMode.Error
	else
		assert(FailMode[failMode], "Selene is opinionated")
	end

	local deserializer = self:FindDeserializer(serializedTarget.type)
	if deserializer == nil then
		error(("No deserializer found for type: %s"):format(serializedTarget.type))
	end

	local ok, r2 = deserializer(serializedTarget, self.man)
	if not ok then
		if failMode == FailMode.Error then
			error(("Deserializer failed for type %s: %s"):format(serializedTarget.type, r2))
		elseif failMode == FailMode.Warn then
			warn(("Deserializer failed for type %s: %s"):format(serializedTarget.type, r2))
		end
	end
	
	return r2
end

function Serializers:Extract(serializedTarget)
	if type(serializedTarget) ~= "table" then
		return serializedTarget
	end

	local extractor = self:FindExtractor(serializedTarget.type)
	if extractor == nil then
		error(("No extractor found for type: %s"):format(serializedTarget.type))
	end

	return extractor(serializedTarget)
end

function Serializers:RegisterSerializer(class, serializer)
	self._serializers[class] = serializer
end

function Serializers:RegisterDeserializer(name, deserializer)
	assert(type(name) == "string", "Deserializer name must be a string")
	self._deserializers[name] = deserializer
end

local function find(object, map)
	if map[object] then
		return map[object]
	end

	local typeOfEntry = map[typeof(object)]
	if typeOfEntry then
		return typeOfEntry
	end

	local metatable = getmetatable(object)
	if metatable then
		return find(metatable, map)
	end

	if object.Inherits then
		return find(object.Inherits, map)
	end
end

function Serializers:FindSerializer(object)
	return find(object, self._serializers)
end

function Serializers:FindDeserializer(type)
	return self._deserializers[type]
end

function Serializers:FindExtractor(type)
	return self._extractors[type]
end

return Serializers