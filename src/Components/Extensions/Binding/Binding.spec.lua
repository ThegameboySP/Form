local BaseComponent = require(script.Parent.Parent.Parent.Form.BaseComponent)
local Manager = require(script.Parent.Parent.Parent.Form.Manager)
local spy = require(script.Parent.Parent.Parent.Testing.spy)

local TestComponent = BaseComponent:extend("TestComponent", {
	EmbeddedComponents = {"Binding"};
})

local function newBase(isTesting, class)
	local resolvedClass = class or TestComponent
	local man = Manager.new("test")
	if isTesting then
		man.Binding:DisconnectFromRunService()
	end

	man:RegisterComponent(class or resolvedClass)
	man.IsTesting = isTesting

	local comp = man:GetOrAddComponent(Instance.new("Folder"), resolvedClass)
	return man.Binding, comp.Binding, comp
end

return function()	
	it("Bind: should bind to component, destructing when component destroys", function()
		local ext, embedded, comp = newBase(true)
		local called = 0
		embedded:Bind("PostSimulation", function()
			called += 1
		end)
		ext.PostSimulation:Fire()

		comp:Destroy()
		ext.PostSimulation:Fire()
		expect(called).to.equal(1)
	end)

	it("Bind: should bind to component, destructing when called", function()
		local ext, embedded = newBase(true)
		local called = 0
		local destruct = embedded:Bind("PostSimulation", function()
			called += 1
		end)
		ext.PostSimulation:Fire()

		destruct()
		destruct()
		ext.PostSimulation:Fire()
		expect(called).to.equal(1)
	end)

	it("Connect: should connect to internal event names", function()
		local ext, embedded = newBase(true)
		local calledTimes = 0
		embedded:Bind("PostSimulation", function()
			calledTimes += 1
		end)

		ext.PostSimulation:Fire()
		expect(calledTimes).to.equal(1)
	end)

	it("Connect: should connect to RunService events", function()
		local ext = newBase(false)
		local called = false
		local destruct
		destruct = ext:Connect("PostSimulation", function()
			destruct()
			called = true
		end)
		
		ext.PostSimulation:Wait()
		ext.PostSimulation:Wait()
		expect(called).to.equal(true)
	end)

	it("should pause and unpause", function()
		local _, _, c = newBase(true)
		local b = c.Binding

		expect(b:IsPaused()).to.equal(false)
		b:Pause()
		b:Pause()
		expect(b:IsPaused()).to.equal(true)
		b:Unpause()
		b:Unpause()
		expect(b:IsPaused()).to.equal(false)
	end)

	it("should only fire Paused and Unpaused when there was a change", function()
		local _, _, c = newBase(true)
		local b = c.Binding
		local tbl = {}
		local func = spy(tbl)

		c:On("Paused", func)
		c:On("Unpaused", func)

		b:Pause()
		b:Pause()
		expect(tbl.Count).to.equal(1)
		expect(tbl.Params[1][1]).to.equal(nil)

		b:Unpause()
		b:Unpause()
		expect(tbl.Count).to.equal(2)
		expect(tbl.Params[2][1]).to.equal(nil)
	end)

	it("should suppress all PauseWrap'ed events when paused", function()
		local _, _, c = newBase(true)
		local b = c.Binding
		local tbl = {}
		local func = b:PauseWrap(spy(tbl))

		b:Pause()
		c:On("Test", func)
		c:Fire("Test")

		local bindable = Instance.new("BindableEvent")
		bindable.Event:Connect(func)
		bindable:Fire()

		expect(tbl.Count).to.equal(0)
	end)

	it("Wait: should yield the thread until the given time", function()
		local ext, _, c = newBase(true)
		local resumed = false
		coroutine.wrap(function()
			c.Binding:Wait(2)
			resumed = true
		end)()
		c.TimeFunction = function()
			return os.clock() + 2
		end

		expect(resumed).to.equal(false)
		ext.Defer:Fire()
		expect(resumed).to.equal(true)
	end)

	it("Wait: should not count time when paused", function()
		local ext, _, c = newBase(true)
		local resumed = false
		coroutine.wrap(function()
			c.Binding:Wait(2)
			resumed = true
		end)()

		c.TimeFunction = function()
			return os.clock() + 8
		end

		c.Binding:Pause()
		ext.Defer:Fire()
		expect(resumed).to.equal(false)

		c.Binding:Unpause()
		ext.Defer:Fire()
		expect(resumed).to.equal(true)
	end)
end