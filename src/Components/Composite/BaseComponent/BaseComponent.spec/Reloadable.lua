local BaseComponent = require(script.Parent.Parent)
local Reloadable = BaseComponent:extend("Reloadable")

function Reloadable.mapConfig(config)
	config.Mapped = true
	return config
end

function Reloadable.mapState(config, state)
	config.Time = config.Time or 1

	return {
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
	self:subscribeAnd("State", function(state)
		if state.Name == "Default" then
			self:ChangeState("Default", state)
		elseif state.Name == "Next" then
			self:ChangeState("Next", state)
		end
	end)
end

function Reloadable:OnReload()
	self.reloadMaid:DoCleaning()
end

function Reloadable:ChangeState(name, args)
	local methodName = name .. "State"
	assert(self[methodName], "Method does not exist!")

	self:setState({
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
		self:setState({State = {TimeLeft = self.sub(1)}})
		if self.state.State.TimeLeft <= 0 then
			self:ChangeState("Next")
		end
	end))
end

function Reloadable:NextState()
	local maid = self.maid:AddId(self.Maid.new(), "state")
	
	maid:Add(self:subscribeAnd("IsBarking", function(isBarking)
		if isBarking then
			self:Fire("Bark!")
		end
	end))
end

return Reloadable