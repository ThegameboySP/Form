local BaseComponent = require(script.Parent.BaseComponent)

local DamageComponent = setmetatable({}, {__index = BaseComponent})
DamageComponent.ComponentName = "DamageComponent"
DamageComponent.__index = DamageComponent

function DamageComponent.getInterfaces(t)
	return {
		IConfiguration = t.strictInterface({
			Damage = t.number;
		});
	}
end


function DamageComponent.new(instance, config)
	return setmetatable(BaseComponent.new(instance, config), DamageComponent)
end


function DamageComponent:Main()
	self:bind(self.instance.Touched, function(part)
		local hum = part.Parent:FindFirstChild("Humanoid")
		if hum == nil then return end

		hum.Health -= self.config.Damage
	end)
end

return DamageComponent