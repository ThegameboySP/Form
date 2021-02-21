local ComponentsUtils = require(script.Parent.ComponentsUtils)
local t = require(script.Parent.Modules.t)
local Event = require(script.Parent.Modules.Event)

local Components = {}
Components.__index = Components

local ERRORED = "%s: Component errored:\n%s\nThis trace: %s"
local NO_COMPONENT_ERROR = "Instance %q does not have component %q!"

function Components.new(man, src, name)
	return setmetatable({
		ComponentAdded = Event.new();
		ComponentRemoved = Event.new();

		_manager = man;
		_src = src;
		_name = name or error("No component name!");
		_iConfiguration = src.getInterfaces(t).IConfiguration;

		_components = {};
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

	if not comp.__synced then
		ComponentsUtils.mergeStateValueObjects(
			ComponentsUtils.getOrMakeComponentStateFolder(instance, self._name),
			deltaState
		)
	end

	for key, value in next, deltaState do
		comp.state[key] = value
	end
end


function Components:GetState(instance)
	local comp = self._components[instance]
	if comp == nil then
		error(NO_COMPONENT_ERROR:format(instance:GetFullName(), self._name))
	end

	return ComponentsUtils.shallowCopy(comp.state)
end


function Components:Subscribe(instance, stateName, handler)
	local stateFdr = ComponentsUtils.getOrMakeComponentStateFolder(instance, self._name)

	return ComponentsUtils.subscribeComponentState(stateFdr, function(name, value)
		if name ~= stateName then return end
		handler(value)
	end)
end


function Components:InitComponent(instance, config, synced)
	config = ComponentsUtils.mergeConfig(instance, self._name, config)

	if self._iConfiguration then
		local ok, err = self._iConfiguration(config)
		if not ok then
			error(
				("Bad configuration for component %q under %q:\n%s"):format(self._name, instance:GetFullName(), err)
			)
		end
	end

	local object, state = self._src.new(instance, config)
	object.manager = self._manager
	object.state = ComponentsUtils.getComponentState(
		ComponentsUtils.getOrMakeComponentStateFolder(instance, self._name)
	)
	object.__synced = synced

	self._components[instance] = object
	if state then
		self:SetState(instance, state)
	end

	return config
end


function Components:RunComponentMain(instance)
	if self._src.Main then
		local object = self._components[instance]

		local co = coroutine.create(self._src.Main)
		local ok, err = coroutine.resume(co, object)

		if not ok then
			error(ERRORED:format(instance:GetFullName(), err, debug.traceback(co)))
		end
	end
end


function Components:AddComponent(instance, config, synced)
	local newConfig = self:InitComponent(instance, config, synced)
	self:RunComponentMain(instance)

	self.ComponentAdded:Fire(instance, newConfig)

	return newConfig
end


function Components:RemoveComponent(instance)
	local component = self._components[instance]
	local ok, err = pcall(self._src.Destroy, component)

	self._components[instance] = nil

	self.ComponentRemoved:Fire(instance)

	if not ok then
		error(ERRORED:format(instance:GetFullName(), err, ":Destroy"))
	end
end


function Components:IsAdded(instance)
	return self._components[instance] ~= nil
end

return Components