local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local ComponentsUtils = require(script.Parent.ComponentsUtils)
local t = require(script.Parent.Modules.t)
local Symbol = require(script.Parent.Modules.Symbol)
local TimeCycle = require(script.Parent.TimeCycle)

local Components = {}
Components.__index = Components

local ERRORED = "%s: Component errored:\n%s\nThis trace: %s"
local NO_COMPONENT_ERROR = "Instance %q does not have component %q!"
local NULL = Symbol.named("null")

function Components.new(man, src, name)
	local interfaces = src.getInterfaces(t)
	return setmetatable({
		_manager = man;
		_src = src;
		_name = name or error("No component name!");
		_iConfiguration = interfaces.IConfiguration;
		_iInstance = interfaces.IInstance;

		_components = {};
		_cycles = {};
	}, Components)
end


function Components:Clear()
	for instance in next, self._components do
		self:RemoveComponent(instance)
	end
end


function Components:SetState(instance, deltaState)
	local comp = self._components[instance]
	if comp == nil then
		error(NO_COMPONENT_ERROR:format(instance:GetFullName(), self._name))
	end

	for key, value in next, deltaState do
		if value == NULL then
			comp.state[key] = nil
		else
			comp.state[key] = value
		end
	end
end


function Components:GetState(instance)
	local comp = self._components[instance]
	if comp == nil then
		error(NO_COMPONENT_ERROR:format(instance:GetFullName(), self._name))
	end

	return ComponentsUtils.shallowCopy(comp.state)
end


function Components:NewComponent(instance, config, synced)
	config = ComponentsUtils.mergeConfig(instance, self._name, config)

	if self._iConfiguration then
		local ok, err = self._iConfiguration(config)
		if not ok then
			warn(
				("Bad configuration for component %q under %q:\n%s"):format(self._name, instance:GetFullName(), err)
			)
			return nil
		end
	end

	if self._iInstance then
		local ok, err = self._iInstance(instance)
		if not ok then
			warn(
				("Bad instance for component %q under %q:\n%s"):format(self._name, instance:GetFullName(), err)
			)
			return nil
		end
	end

	local object = self._src.new(instance, config)
	object.man = self._manager
	object.state = ComponentsUtils.getComponentState(
		ComponentsUtils.getOrMakeComponentStateFolder(instance, self._name)
	)
	object.__synced = synced

	self._components[instance] = object

	return object, config
end


function Components:PreInitComponent(instance)
	local object = self._components[instance]
	if object.PreInit then
		object:PreInit()
	end
end


function Components:InitComponent(instance)
	local object = self._components[instance]
	if object.Init then
		object:Init()
	end
end


function Components:RunComponentMain(instance)
	CollectionService:AddTag(instance, self._name)
	
	if self._src.Main then
		local object = self._components[instance]
		if object == nil then
			warn(("No component called %s for %s"):format(self._name, instance:GetFullName()))
			return
		end

		local co = coroutine.create(self._src.Main)
		local ok, err = coroutine.resume(co, object)

		if not ok then
			warn(ERRORED:format(instance:GetFullName(), err, debug.traceback(co)))
		end
	end
end


function Components:AddComponent(instance, config, synced)
	if self._components[instance] then return end

	local obj, newConfig = self:NewComponent(instance, config, synced)
	if newConfig == nil then
		return nil
	end

	self:PreInitComponent(instance)
	self:InitComponent(instance)
	self:RunComponentMain(instance)

	return obj, newConfig
end


function Components:RemoveComponent(instance)
	local component = self._components[instance]
	if component == nil then return end
	
	local ok, err = pcall(self._src.Destroy, component)

	self._components[instance] = nil

	if not ok then
		error(ERRORED:format(instance:GetFullName(), err, ":Destroy"))
	end
end


function Components:GetComponent(instance)
	return self._components[instance]
end


function Components:SetCycle(instance, name, cycleLen)
	local iCycles = self._cycles[instance]
	if iCycles == nil then
		self._cycles[instance] = {}
		iCycles = self._cycles[instance]
	end

	local cycle = iCycles[name]
	if cycle == nil then
		cycle = TimeCycle.new(cycleLen)
		iCycles[name] = cycle
	else
		cycle:SetLength(cycleLen)
	end

	return cycle
end


function Components:GetCycle(instance, name)
	local iCycles = self._cycles[instance]
	if iCycles == nil then
		return nil
	end

	return iCycles[name]
end


function Components:FireEvent(instance, eventName, ...)
	if not self:IsAdded(instance) then return end
	
	local comp = self._components[instance]
	if comp:hasEvent(eventName) then
		comp:fireEvent(eventName, ...)
	end
end


function Components:ConnectEvent(instance, eventName, handler)
	local comp = self._components[instance]
	if comp == nil then
		error(NO_COMPONENT_ERROR:format(instance:GetFullName(), self._name))
	end

	if not comp:hasEvent(eventName) then
		error(("No event by name of %s under instance %s for component %s")
			:format(eventName, instance:GetFullName(), self._name))
	end

	return comp:connectEvent(eventName, handler)
end


function Components:IsAdded(instance)
	return self._components[instance] ~= nil
end

return Components