local BaseComponent = require(script.Parent.BaseComponent)
-- local GameBridge = require(script.Parent.GameBridge)

local S_TestComponent = setmetatable({}, {__index = BaseComponent})
S_TestComponent.ComponentName = "TestComponent"
S_TestComponent.__index = S_TestComponent

function S_TestComponent.getInterfaces(t)
	return {
		IConfiguration = t.strictInterface({
			shouldExplode = t.boolean;
			test = t.optional(t.any);
		});
	}
end


function S_TestComponent.new(instance, props)
	return setmetatable(BaseComponent.new(instance, props), S_TestComponent), {
		state1 = "test";
		firedTimes = 0;
	}
end


function S_TestComponent:Main()
	self:subscribeAnd("state1", function(_)
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

return S_TestComponent