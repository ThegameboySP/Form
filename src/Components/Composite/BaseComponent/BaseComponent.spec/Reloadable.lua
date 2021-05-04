local BaseComponent = require(script.Parent.Parent)
local Reloadable = BaseComponent:extend("Reloadable")

function Reloadable.mapState(config, state)
	return {
		IsBarking = config.ShouldBark;
		State = state.State or {
			Name = "Default";
			TimeLeft = math.min(state:get("State", "TimeLeft") or config.Time, config.Time);
		};
	}
end

function Reloadable:Init()
	if not self.decorMaid then
		self.decorMaid = self.Maid.new()
	end
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

	maid:Add(self:on("TimeElapsed", function()
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
			self:fire("Bark!")
		end
	end))
end

function Reloadable:Destroy(isReloading)
	if isReloading then
		self.maid:DoCleaning()
	else
		self.maid:DoCleaning()
		self.decorMaid:DoCleaning()
	end
end

return Reloadable