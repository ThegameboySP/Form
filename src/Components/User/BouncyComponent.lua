local BaseComponent = require(script.Parent.BaseComponent)

local BouncyComponent = setmetatable({}, {__index = BaseComponent})
BouncyComponent.ComponentName = "BouncyComponent"
BouncyComponent.__index = BouncyComponent

function BouncyComponent.getInterfaces(t)
	return {
		IConfiguration = t.strictInterface({
			jumpPower = t.optional(t.number);
		});
	}
end


function BouncyComponent.new(instance, props)
	return setmetatable(BaseComponent.new(instance, props), BouncyComponent)
end


function BouncyComponent:Main()
	self.instance.Touched:Connect(function(part)
		local char = part.Parent
		if not char:FindFirstChild("Humanoid") then return end

		char.Humanoid.JumpPower = self.props.jumpPower or 100
		char.Humanoid.Jump = true
		char.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end)
end

return BouncyComponent