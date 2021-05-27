local ComponentMode = require(script.Parent.Parent.Shared.ComponentMode)
local runCoroutineOrWarn = require(script.Parent.runCoroutineOrWarn)
local SignalMixin = require(script.Parent.SignalMixin)
local Symbol = require(script.Parent.Parent.Modules.Symbol)
local IKeywords = require(script.Parent.IKeywords)

local ComponentCollection = {}
ComponentCollection.__index = ComponentCollection

local BASE = Symbol.named("base")

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

	class:cache()
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
	local isNew, comp, id, newKeywords = self:_newComponent(ref, classResolvable, keywords)
	if not isNew then
		return comp, id
	end

	self:_runComponent(comp, newKeywords)
	return comp, id
end


local function isWeak(comps)
	for _, tbl in pairs(comps) do
		if not tbl.isWeak then
			return false
		end
	end

	return true
end

function ComponentCollection:_newComponent(ref, classResolvable, keywords)
	assert(typeof(ref) == "Instance")
	keywords = keywords or {}
	assert(IKeywords(keywords))

	local class = self:_resolveOrError(classResolvable)
	if self:HasComponent(ref, class) then
		local tbl = self._componentsByRef[ref][class]
		if (not not tbl.isWeak) ~= (not not keywords.isWeak) then
			error("Weak components must be consistent!")
		end

		local comp = tbl.comp
		return false, comp, comp.Layers:SetConfig(comp.Layers:NewId(), keywords.config)
	end

	if self._componentsByRef[ref] == nil and keywords.isWeak then
		return false, nil
	end

	local config = keywords.config or {}
	local mode = keywords.mode or ComponentMode.Default

	local comp = class.new(ref, config)
	comp.man = self._man
	comp.mode = mode
	comp:On("Destroying", function()
		local comps = self._componentsByRef[ref]
		comps[class] = nil
		self:Fire("ComponentRemoved", comp)

		if not next(comps) or isWeak(comps) then
			self:RemoveRef(ref)
		end
	end)
	comp:PreStart()

	if self._componentsByRef[ref] == nil then
		self._componentsByRef[ref] = {}
		self:Fire("RefAdded", ref)
	end
	self._componentsByRef[ref][class] = {comp = comp, isWeak = keywords.isWeak}

	return true, comp, BASE, {config = config, mode = mode, isWeak = keywords.isWeak}
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
	return comp.ref:GetFullName() .. ": Coroutine errored:\n%s\nTraceback: %s"
end


function ComponentCollection:_runComponent(comp, keywords)
	local ok, err = pcall(comp.Start, comp, {
		state = keywords.state;
		config = keywords.config;
		layers = keywords.layers;
	})

	if ok then
		comp.initialized = true
		self:Fire("ComponentAdded", comp, keywords)
	else
		warn(err)
	end
end


function ComponentCollection:BulkAddComponent(refs, classResolvables, keywords)
	local tbls = {}
	local comps = {}

	for i, ref in ipairs(refs) do
		if self:HasComponent(ref, classResolvables[i]) then continue end
		local class = self:_resolveOrError(classResolvables[i])
		local isNew, comp, id, newKeywords = self:_newComponent(ref, class, keywords[i])
		if not isNew then
			table.insert(comps, {comp, id, nil})
			continue
		end

		table.insert(tbls, {comp, id, newKeywords})
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
			tbl[1].initialized = true
			table.insert(tbls4, tbl)
		end
	end

	for _, tbl in ipairs(tbls4) do
		local comp = tbl[1]
		local id = tbl[2]
		table.insert(comps, {comp, id})
		self:Fire("ComponentAdded", comp, tbl[3])
	end

	return comps
end


function ComponentCollection:RemoveRef(ref)
	local comps = self._componentsByRef[ref]
	if comps == nil then return end
	local profile = self._man:GetProfile(ref)
	if profile.destroying then return end

	profile.destroying = true
	self:Fire("RefRemoving", ref)

	for _, tbl in next, comps do
		self:RemoveComponent(ref, tbl.comp.BaseName)
	end
	self._componentsByRef[ref] = nil

	self:Fire("RefRemoved", ref)
end


function ComponentCollection:RemoveComponent(ref, classResolvable)
	local class = self:_resolveOrError(classResolvable)
	local comps = self._componentsByRef[ref]
	local tbl = comps and comps[class]
	if not tbl then return end

	-- Will trigger the connection defined in :GetOrMakeComponent.
	tbl.comp:Destroy()
	comps[class] = nil
end


function ComponentCollection:GetComponent(ref, classResolvable)

end


return SignalMixin.wrap(ComponentCollection)