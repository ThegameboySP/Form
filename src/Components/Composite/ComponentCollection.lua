local ComponentsUtils = require(script.Parent.Parent.Shared.ComponentsUtils)
local ComponentMode = require(script.Parent.Parent.Shared.ComponentMode)
local runCoroutineOrWarn = require(script.Parent.runCoroutineOrWarn)
local SignalMixin = require(script.Parent.SignalMixin)

local ComponentCollection = {}
ComponentCollection.__index = ComponentCollection

function ComponentCollection.new(man)
	return SignalMixin.new(setmetatable({
		_man = man;
		
		_classesByName = {};
		_classesByRef = {};
		_componentsByRef = {};
	}, ComponentCollection))
end

function ComponentCollection:Register(class)
	local name = class.BaseName
	assert(type(name) == "string", "Expected 'string'")
	assert(type(class) == "table", "Expected 'table'")

	assert(self._classesByName[name] == nil, "A class already exists by this name!")

	self._man.Classes[name] = class
	self._classesByName[name] = class
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
	local isNew, comp, newKeywords = self:_newComponent(ref, classResolvable, keywords)
	if not isNew then
		return comp
	end

	self:_runComponent(comp, newKeywords)
	return comp
end


function ComponentCollection:_newComponent(ref, classResolvable, keywords)
	assert(typeof(ref) == "Instance")
	keywords = keywords or {}

	local class = self:_resolveOrError(classResolvable)
	if self:HasComponent(ref, class) then
		local comp = self._componentsByRef[ref][class]
		return false, comp:newMirror(keywords.config)
	end

	local config = keywords.config or {}
	local mode = keywords.mode or ComponentMode.Default
	
	local resolvedConfig = self._man:RunHooks("GetConfig", ref, class.BaseName)
	resolvedConfig = ComponentsUtils.shallowMerge(config, resolvedConfig)

	local comp = class.new(ref, config)
	comp.man = self._man
	comp.mode = mode
	comp:On("Destroying", function()
		self._componentsByRef[ref][class] = nil
		self:Fire("ComponentRemoved", ref, comp)

		if next(self._componentsByRef[ref]) == nil then
			self:RemoveRef(ref)
		end
	end)

	if self._componentsByRef[ref] == nil then
		self._componentsByRef[ref] = {}
		self:Fire("RefAdded", ref)
	end
	self._componentsByRef[ref][class] = comp

	return true, comp, {config = resolvedConfig, mode = mode}
end


function ComponentCollection:HasComponent(ref, classResolvable)
	local class = self:_resolveOrError(classResolvable)

	if
		self._componentsByRef[ref]
		and self._componentsByRef[ref][class]
	then
		return true
	end

	return false
end


local function errored(_, comp)
	return comp.instance:GetFullName() .. ": Coroutine errored:\n%s\nTraceback: %s"
end


function ComponentCollection:_runComponent(comp, keywords)
	local instance = comp.instance
	local ok = runCoroutineOrWarn(errored, comp.PreInit, comp)
		and runCoroutineOrWarn(errored, comp.Init, comp)
		and runCoroutineOrWarn(errored, comp.Main, comp)
	
	if ok then
		self:Fire("ComponentAdded", instance, comp, keywords)
	end
end


function ComponentCollection:BulkAddComponent(refs, classResolvables, keywords)
	local tbls = {}

	for i, ref in ipairs(refs) do
		if self:HasComponent(ref, classResolvables[i]) then continue end
		local class = self:_resolveOrError(classResolvables[i])
		local isNew, comp, newKeywords = self:_newComponent(ref, class, keywords[i])
		if not isNew then continue end

		table.insert(tbls, {comp, newKeywords})
	end

	local tbls2 = {}
	for _, tbl in ipairs(tbls) do
		local ok = runCoroutineOrWarn(errored, tbl[1].PreInit, tbl[1])
		if ok then
			table.insert(tbls2, tbl)
		end
	end

	local tbls3 = {}
	for _, tbl in ipairs(tbls2) do
		local ok = runCoroutineOrWarn(errored, tbl[1].Init, tbl[1])
		if ok then
			table.insert(tbls3, tbl)
		end
	end

	local tbls4 = {}
	for _, tbl in ipairs(tbls3) do
		local ok = runCoroutineOrWarn(errored, tbl[1].Main, tbl[1])
		if ok then
			table.insert(tbls4, tbl)
		end
	end

	local comps = {}
	for _, tbl in ipairs(tbls4) do
		table.insert(comps, tbl[1])
		local comp = tbl[1]
		self:Fire("ComponentAdded", comp.instance, comp, tbl[2])
	end

	return comps
end


function ComponentCollection:RemoveRef(ref)
	local comps = self._componentsByRef[ref]
	if comps == nil then return end
	local profile = self._man:GetProfile(ref)
	if profile.destroying then return end

	profile.destroying = true
	for _, comp in next, comps do
		self:RemoveComponent(ref, comp.BaseName)
	end
	self._componentsByRef[ref] = nil

	self:Fire("RefRemoved", ref)
end


function ComponentCollection:RemoveComponent(ref, classResolvable)
	local class = self:_resolveOrError(classResolvable)
	local comps = self._componentsByRef[ref]
	local comp = comps and comps[class]
	if not comp then return end

	-- Will trigger the connection defined in :GetOrMakeComponent.
	comp:Destroy()
	comps[comp] = nil
end


function ComponentCollection:GetComponent(ref, classResolvable)

end


return SignalMixin.wrap(ComponentCollection)