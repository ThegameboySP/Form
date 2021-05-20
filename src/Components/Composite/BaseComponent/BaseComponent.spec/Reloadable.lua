local BaseComponent = require(script.Parent.Parent)
local Reloadable = BaseComponent:extend("Reloadable")

function Reloadable.mapConfig(config)
	config.Mapped = true
	config.MappedTimes = (config.MappedTimes or 0) + 1
	return config
end

function Reloadable.mapState(config, state)
	config.Time = config.Time or 1

	return {
		Mapped = true;
		Test = state.Test;
		IsBarking = not not config.ShouldBark;
		State = state.State or {
			Name = "Default";
			TimeLeft = math.min(state:get("State", "TimeLeft") or config.Time, config.Time);
		};
	}
end

function Reloadable:Init()
	self.reloadMaid = self.Maid.new()
end

function Reloadable:Main()
	self:SubscribeAnd("State", function(state)
		if state.Name == "Default" then
			self:ChangeState("Default", state)
		elseif state.Name == "Next" then
			self:ChangeState("Next", state)
		end
	end)
end

function Reloadable:OnNewConfig()
	self.reloadMaid:DoCleaning()
end

function Reloadable:ChangeState(name, args)
	local methodName = name .. "State"
	assert(self[methodName], "Method does not exist!")

	self:SetState({
		State = self.util.union(
			args or {},
			{
				Name = name;
			}
		)
	})

	return self[methodName](self, args)
end

function Reloadable:DefaultState()
	local maid = self.maid:AddId(self.Maid.new(), "state")

	maid:Add(self:On("TimeElapsed", function()
		self:SetState({State = {TimeLeft = self.sub(1)}})
		if self.state.State.TimeLeft <= 0 then
			self:ChangeState("Next")
		end
	end))
end

function Reloadable:NextState()
	local maid = self.maid:AddId(self.Maid.new(), "state")
	
	maid:Add(self:SubscribeAnd("IsBarking", function(isBarking)
		if isBarking then
			self:Fire("Bark!")
		end
	end))
end

return Reloadable