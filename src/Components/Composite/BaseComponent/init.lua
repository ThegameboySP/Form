local Maid = require(script.Parent.Parent.Modules.Maid)

local NetworkMode = require(script.Parent.Parent.Shared.NetworkMode)
local SignalMixin = require(script.Parent.SignalMixin)

local BaseComponent = SignalMixin.wrap({
	NetworkMode = NetworkMode.ServerClient;
	ClassName = "BaseComponent";
	isComponent = true;
})
BaseComponent.__index = BaseComponent

local DESTROYED_ERROR = function()
	error("Cannot run a component that is destroyed!")
end

function BaseComponent.new(ref)
	return SignalMixin.new(setmetatable({
		ref = ref;
		maid = Maid.new();
		
		isDestroyed = false;
		isInitialized = false;
	}, BaseComponent))
end

function BaseComponent:run(ref, keywords)
	local comp = self.new(ref, keywords)
	comp:Start()
	return comp, "base"
end

function BaseComponent:extend(name, structure)
	structure = structure or {}
	structure.ClassName = name

	setmetatable(structure, self)
	structure.__index = structure

	function structure.new(ref)
		return setmetatable(self.new(ref), structure)
	end

	return structure
end

function BaseComponent:Destroy(...)
	self:Fire("Destroying")
	self.maid:DoCleaning(...)
	
	self.Init = DESTROYED_ERROR
	self.Main = DESTROYED_ERROR

	self.isDestroyed = true
	self:Fire("Destroyed")
	self:DisconnectAll()
end

function BaseComponent:GetClass()
	return getmetatable(self)
end

function BaseComponent:Start()
	if self.isInitialized then return end
	
	if self.Init then
		self:Init()
	end

	if self.Main then
		coroutine.wrap(self.Main)(self)
	end

	self.isInitialized = true
end

do
	local Fire = BaseComponent.Fire
	function BaseComponent:Fire(key, ...)
		if type(key) == "string" then
			local method = self["On" .. key]
			if type(method) == "function" then
				method(self, ...)
			end
		end

		Fire(self, key, ...)
	end
end

function BaseComponent:Bind(event, handler)
	return self.maid:Add(event:Connect(handler))
end

return BaseComponent