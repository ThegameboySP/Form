local BaseComponent = require(script.Parent.BaseComponent)
-- local GameBridge = require(script.Parent.GameBridge)

local TestComponent = setmetatable({}, {__index = BaseComponent})
TestComponent.ComponentName = "TestComponent"
TestComponent.__index = TestComponent

local IS_SERVER = game:GetService("RunService"):IsServer()

function TestComponent.getInterfaces(t)
	return {
		IConfiguration = t.strictInterface({
			shouldExplode = t.boolean;
			test = t.optional(t.any);
		});
	}
end


function TestComponent.new(instance, props)
	return setmetatable(BaseComponent.new(instance, props), TestComponent), {
		state1 = "test";
		firedTimes = 0;
	}
end


function TestComponent:Main()
	if not IS_SERVER then return end

	self:subscribeAnd("state1", function(currentValue)
		print(currentValue)
		self:setState({
			firedTimes = self.state.firedTimes + 1;
		})
		print(self.state.firedTimes)
	end)

	-- if self.props.shouldExplode then
	-- 	self:FireInstanceEvent("Explosion")
	-- end

	-- GameBridge.ColosseumDoor.Parent = GameBridge.ColosseumDoorFrame
end

return TestComponent