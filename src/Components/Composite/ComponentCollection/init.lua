local Root = require(script.Root)

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
	assert(type(class) == "table", "Expected 'table'")
	local name = class.ClassName
	assert(type(name) == "string", "Expected 'string'")
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


local function errored(_, comp)
	return comp.ref:GetFullName() .. ": Coroutine errored:\n%s\nTraceback: %s"
end


local function run(tbls, methodName)
	local new = {}

	for _, tbl in ipairs(tbls) do
		local shouldRun, comp = tbl[1], tbl[2]
		if shouldRun then
			local ok = runCoroutineOrWarn(errored, comp[methodName], comp)
			if ok then
				table.insert(new, tbl)
			end
		else
			table.insert(new, tbl)
		end
	end

	return tbls
end

function ComponentCollection:BulkAddComponent(refs, classResolvables, keywordsCollection)
	local tbls = {}
	local ids = {}

	for i, ref in ipairs(refs) do
		local class = self:ResolveOrError(classResolvables[i])
		local keywords = keywordsCollection[i] or {}
		-- local comp, id = self:_newComponent(ref, class, keywords)
		ids[comp] = ids[comp] or {}
		table.insert(ids[comp], id)

		table.insert(tbls, {id == "base", comp, keywords.config})
	end

	local tbls2 = run(tbls, "Init")
	local tbls3 = run(tbls2, "Main")

	local comps = {}
	local added = {}
	for _, tbl in ipairs(tbls3) do
		local didRun = tbl[1]
		local comp = tbl[2]
		local config = tbl[3]
		if added[comp] then continue end
		added[comp] = true

		table.insert(comps, comp)
		if not didRun then continue end

		comp.isInitialized = true
		self:Fire("ComponentAdded", comp, config)
	end

	return comps, ids
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