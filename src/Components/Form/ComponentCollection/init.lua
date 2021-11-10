local Root = require(script.Root)
local Types = require(script.Parent.Types)

local ComponentCollection = {}
ComponentCollection.__index = ComponentCollection

function ComponentCollection.new(man, callbacks)
	return setmetatable({
		_man = man;
		
		_classesByName = {};
		_classesByRef = {};
		_rootByRef = {};

		_callbacks = callbacks;
	}, ComponentCollection)
end

function ComponentCollection:Register(class)
	assert(Types.ComponentDefinition(class))
	local name = class.ClassName
	assert(self._classesByName[name] == nil, "A class already exists by this name!")

	if class.NetworkMode == "Server" and not self._man.IsServer then
		error("Cannot register a server component on the client!")
	elseif class.NetworkMode == "Client" and self._man.IsServer then 
		error("Cannot register a client component on the server!")
	end

	self._classesByName[name] = class
	self._classesByRef[class] = class
	
	self._callbacks.ClassRegistered(class)
end


function ComponentCollection:Resolve(classResolvable)
	return self._classesByName[classResolvable]
		or self._classesByRef[classResolvable]
end


function ComponentCollection:ResolveOrError(classResolvable)
	return self:Resolve(classResolvable)
		or error("No registered class: " .. tostring(classResolvable))
end


function ComponentCollection:_getOrAddWrapper(ref)
	local wrapper = self._rootByRef[ref]
	if wrapper == nil then
		wrapper = Root.new(self._man, ref, self._callbacks)
		self._rootByRef[ref] = wrapper

		self._callbacks.RefAdded(ref)
	end

	return wrapper
end


function ComponentCollection:GetOrAddComponent(ref, classResolvable, layer)
	assert(typeof(ref) == "Instance", "Expected 'Instance'")
	return self:_getOrAddWrapper(ref):GetOrAddComponent(classResolvable, layer)
end


function ComponentCollection:GetOrAddComponentLoadless(ref, classResolvable, layer)
	assert(typeof(ref) == "Instance", "Expected 'Instance'")
	return self:_getOrAddWrapper(ref):GetOrAddComponentLoadless(classResolvable, layer)
end


function ComponentCollection:BulkAddComponent(refs, classResolvables, layersCollection)
	local comps = {}
	local ids = {}

	for i, ref in ipairs(refs) do
		local resolvable = classResolvables[i]
		local wasAdded = self:GetComponent(ref, resolvable) ~= nil

		local comp, id = self:GetOrAddComponentLoadless(ref, resolvable, layersCollection[i])
		ids[comp] = ids[comp] or {}
		table.insert(ids[comp], id)

		if not wasAdded then
			table.insert(comps, comp)
		end
	end

	for _, comp in ipairs(comps) do
		comp:FireWithMethod("Init", comp.OnInit)
	end

	for _, comp in ipairs(comps) do
		comp:FireWithMethod("Start", comp.OnStart)
	end

	local initializedComps = {}
	local addedComps = {}
	for _, comp in ipairs(comps) do
		if addedComps[comp] then continue end
		addedComps[comp] = true
		table.insert(initializedComps, comp)

		comp:SetInitialized()
	end

	return initializedComps, ids
end


function ComponentCollection:RemoveRef(ref)
	local wrapper = self._rootByRef[ref]
	if wrapper then
		wrapper:Destroy()
	end
end


function ComponentCollection:RemoveComponent(ref, classResolvable)
	local wrapper = self._rootByRef[ref]
	if not wrapper then return end
	wrapper:RemoveComponent(classResolvable)
end


function ComponentCollection:GetComponent(ref, classResolvable)
	local wrapper = self._rootByRef[ref]
	if wrapper then
		return wrapper.added[self:ResolveOrError(classResolvable)]
	end

	return nil
end


return ComponentCollection