local runCoroutineOrWarn = require(script.Parent.runCoroutineOrWarn)
local SignalMixin = require(script.Parent.SignalMixin)
local Symbol = require(script.Parent.Parent.Modules.Symbol)
local IKeywords = require(script.Parent.IKeywords)
local Root = require(script.Root)

local ComponentCollection = {}
ComponentCollection.__index = ComponentCollection

local BASE = Symbol.named("base")

function ComponentCollection.new(man)
	return SignalMixin.new(setmetatable({
		_man = man;
		
		_classesByName = {};
		_classesByRef = {};
		_wrapperByRef = {};
	}, ComponentCollection))
end

function ComponentCollection:Register(class)
	local name = class.BaseName
	assert(type(name) == "string", "Expected 'string'")
	assert(type(class) == "table", "Expected 'table'")
	assert(self._classesByName[name] == nil, "A class already exists by this name!")

	self._classesByName[name] = class
	self._classesByRef[class] = class
	
	self:Fire("ClassRegistered", class)
end


function ComponentCollection:_resolve(classResolvable)
	return self._classesByName[classResolvable]
		or self._classesByRef[classResolvable]
end


function ComponentCollection:_resolveOrError(classResolvable)
	return self:_resolve(classResolvable)
		or error("No registered class: " .. tostring(classResolvable))
end


function ComponentCollection:_getOrAddWrapper(ref)
	local wrapper = self._wrapperByRef[ref]
	if wrapper == nil then
		wrapper = Root:run(ref)
		self._wrapperByRef[ref] = wrapper

		wrapper:On("ComponentAdding", function(...)
			self:Fire("ComponentAdding", ...)
		end)

		wrapper:On("ComponentAdded", function(...)
			self:Fire("ComponentAdded", ...)
		end)
		
		wrapper:On("ComponentRemoved", function(...)
			self:Fire("ComponentRemoved", ...)
		end)

		wrapper:On("Destroyed", function()
			self:RemoveRef(ref)
		end)

		self:Fire("RefAdded", ref)
	end

	return wrapper
end


function ComponentCollection:GetOrAddComponent(ref, classResolvable, keywords)
	keywords = keywords or {}
	local comp, id = self:_newComponent(ref, classResolvable, keywords)
	if id ~= BASE then
		return comp, id
	end

	self:_runComponent(comp, keywords.config)
	return comp, id
end

function ComponentCollection:_newComponent(ref, classResolvable, keywords)
	assert(typeof(ref) == "Instance", "Expected 'Instance'")
	assert(IKeywords(keywords))
	
	local class = self:_resolveOrError(classResolvable)
	local wrapper = self:_getOrAddWrapper(ref)
	if wrapper.added[class] then
		return wrapper:GetOrAddComponent(class, {
			config = keywords.config;
			layers = keywords.layers;
		})
	end

	local comp = wrapper:PreStartComponent(class, {
		config = keywords.config,
		layers = keywords.layers;
		target = ref;
	})
	comp.man = self._man

	return comp, BASE
end


local function errored(_, comp)
	return comp.ref:GetFullName() .. ": Coroutine errored:\n%s\nTraceback: %s"
end


function ComponentCollection:_runComponent(comp, config)
	local ok, err = pcall(comp.Start, comp)

	if ok then
		self._wrapperByRef[comp.ref]:Fire("ComponentAdded", comp, config or {})
	else
		warn(errored(nil, comp):format(err))
	end
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
		local class = self:_resolveOrError(classResolvables[i])
		local keywords = keywordsCollection[i] or {}
		local comp, id = self:_newComponent(ref, class, keywords)
		ids[comp] = ids[comp] or {}
		table.insert(ids[comp], id)

		table.insert(tbls, {id == BASE, comp, keywords.config})
	end

	local tbls2 = run(tbls, "PreInit")
	local tbls3 = run(tbls2, "Init")
	local tbls4 = run(tbls3, "Main")

	local comps = {}
	local added = {}
	for _, tbl in ipairs(tbls4) do
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
	local wrapper = self._wrapperByRef[ref]
	if wrapper == nil then return end
	if wrapper.destroying then return end
	wrapper.destroying = true

	self:Fire("RefRemoving", ref)

	for class in next, wrapper.added do
		self:RemoveComponent(ref, class)
	end
	self._wrapperByRef[ref] = nil

	self:Fire("RefRemoved", ref)
end


function ComponentCollection:RemoveComponent(ref, classResolvable)
	local class = self:_resolveOrError(classResolvable)
	local wrapper = self._wrapperByRef[ref]
	if not wrapper then return end
	local comp = wrapper.added[class]
	if not comp then return end

	-- Will trigger the connection defined in :GetOrMakeComponent.
	comp:Destroy()
end


function ComponentCollection:GetComponent(ref, classResolvable)
	local class = self:_resolveOrError(classResolvable)
	local wrapper = self._wrapperByRef[ref]
	if wrapper == nil then return nil end

	return wrapper.added[class]
end


return SignalMixin.wrap(ComponentCollection)