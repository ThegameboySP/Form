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
	local valueObject = stateFdr:FindFirstChild(stateName)
	if valueObject == nil then
		error(("There is no value object under %q named %q!"):format(instance:GetFullName(), stateName))
	end

	return ComponentsUtils.subscribeComponentState(stateFdr, function(name, value)
		if name ~= stateName then return end
		handler(value)
	end)
end


function Components:InitComponent(instance, props, synced)
	props = ComponentsUtils.mergeProps(instance, self._name, props)

	if self._iConfiguration then
		local ok, err = self._iConfiguration(props)
		if not ok then
			error(
				("Bad configuration for component %q under %q:\n%s"):format(self._name, instance:GetFullName(), err)
			)
		end
	end

	local object, state = self._src.new(instance, props)
	state = state or {}
	object.manager = self._manager
	object.state = state
	object.__synced = synced

	self._components[instance] = object
	self:SetState(instance, state)

	-- local stateFdr = ComponentsUtils.getOrMakeComponentStateFolder(instance, self._name)
	-- ComponentsUtils.subscribeState(stateFdr, function(property, value)
	-- 	self:SetState(instance, {[property.Name] = value})
	-- end)

	return props
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


function Components:AddComponent(instance, props, synced)
	local newProps = self:InitComponent(instance, props, synced)
	self:RunComponentMain(instance)

	self.ComponentAdded:Fire(instance, newProps)

	return newProps
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