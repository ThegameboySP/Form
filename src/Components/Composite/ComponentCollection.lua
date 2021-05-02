local ComponentsUtils = require(script.Parent.Parent.Shared.ComponentsUtils)
local ComponentMode = require(script.Parent.Parent.Shared.ComponentMode)
local runCoroutineOrWarn = require(script.Parent.runCoroutineOrWarn)

local ComponentCollection = {}
ComponentCollection.__index = ComponentCollection

function ComponentCollection.new(man)
	return setmetatable({
		_man = man;
		
		_classesByName = {};
		_classesByRef = {};
		_componentsByRef = {};
		_modeByRef = {};
	}, ComponentCollection)
end


function ComponentCollection:Register(class)
	local name = class.ComponentName
	assert(type(name) == "string", "Expected 'string'")
	assert(type(class) == "table", "Expected 'table'")

	local baseName = ComponentsUtils.getBaseComponentName(name)
	assert(self._classesByName[baseName] == nil, "A class already exists by this name!")

	self._man.Classes[baseName] = class
	self._classesByName[baseName] = class
	self._classesByRef[class] = class
end


function ComponentCollection:_resolve(classResolvable)
	return self._classesByName[classResolvable]
		or self._classesByRef[classResolvable]
end


function ComponentCollection:_resolveOrError(classResolvable)
	return self:_resolve(classResolvable)
		or error("No registered class: " .. tostring(classResolvable))
end


function ComponentCollection:GetOrAddComponent(ref, classResolvable, keywords)
	assert(typeof(ref) == "Instance")

	local class = self:_resolveOrError(classResolvable)
	if
		self._componentsByRef[ref]
		and self._componentsByRef[ref][class]
	then
		return self._componentsByRef[ref][class]
	end

	keywords = keywords or {}
	local config = keywords.config or {}
	local mode = keywords.mode or ComponentMode.DEFAULT
	
	local resolvedConfig = self._man:RunHooks("GetConfig", ref, class.BaseName)
	resolvedConfig = ComponentsUtils.shallowMerge(config, resolvedConfig)

	local comp = class.new(ref, config)
	comp.man = self._man
	comp.mode = mode

	self._componentsByRef[ref] = self._componentsByRef[ref] or {}
	self._componentsByRef[ref][class] = comp
	if mode ~= ComponentMode.DEFAULT then
		self._modeByRef[ref] = mode
	end

	local format = ref:GetFullName() .. ": Coroutine errored:\n%s\nTraceback: %s"
	local ok = runCoroutineOrWarn(format, comp.PreInit, comp)
		and runCoroutineOrWarn(format, comp.Init, comp)
		and runCoroutineOrWarn(format, comp.Main, comp)
	
	if ok then
		self._man:Fire("ComponentAdded", ref, comp, config, keywords)
	end

	return comp
end


function ComponentCollection:RemoveRef(ref)
	local comps = self._componentsByRef[ref]
	if comps == nil then return end

	for comp in next, comps do
		comp:Destroy()
		comps[comp] = nil
	end

	self._componentsByRef[ref] = nil
end


function ComponentCollection:RemoveComponent(ref, classResolvable)
	local class = self:_resolveOrError(classResolvable)
	local comps = self._componentsByRef[ref]
	local comp = comps and comps[class]
	if comp == nil then return end

	comp:Destroy()
	comps[class] = nil

	if next(comps) == nil then
		self:RemoveRef(ref)
	end

	self._man:Fire("ComponentRemoved", ref, comp, comp._mode)
end


function ComponentCollection:GetComponent(ref, classResolvable)

end


return ComponentCollection