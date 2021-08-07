return {
	ClassName = "Sleep",
	Name = "sleep",
	Required = {"Binding"};

	new = function(comp)
		return function(time)
			local duration = time or (1 / 60)
			local bindable = Instance.new("BindableEvent")

			local id
			id = comp.maid:GiveTask(comp.Binding:Connect("PostSimulation", function(delta)
				if comp.Pause and comp.Pause:IsPaused() then return end
				duration -= delta

				if duration <= 0 then
					comp.maid:Remove(id)
					bindable:Fire()
				end
			end))

			local timestamp = os.clock()
			bindable.Event:Wait()
			return os.clock() - timestamp
		end
	end
}