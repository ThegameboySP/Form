local BaseComponent = require(script.Parent.Parent.Parent.Form.BaseComponent)
local Manager = require(script.Parent.Parent.Parent.Form.Manager)
local Binding = require(script.Parent)
local spy = require(script.Parent.Parent.Parent.Testing.spy)

local TestComponent = BaseComponent:extend("TestComponent", {
	EmbeddedComponents = {"Binding"};
})

local function newBase(isTesting, class)
	local resolvedClass = class or TestComponent
	local man = Manager.new("test")
	man:RegisterComponent(class or resolvedClass)
	man.IsTesting = isTesting
	Binding.use(man)

	local comp = man:GetOrAddComponent(Instance.new("Folder"), resolvedClass):Run()
	return man.Binding, comp.Binding, comp
end

return function()
	it("Connect: should accept component signal overrides", function()
		local PostSimulation = Instance.new("BindableEvent")
		local ext = newBase(false)
		ext.PostSimulation = PostSimulation.Event

		local called = false
		ext:Connect("PostSimulation", function()
			called = true
		end)
		PostSimulation:Fire()

		expect(called).to.equal(true)
	end)
	
	it("Bind: should bind to component, destructing when component destroys", function()
		local ext, embedded, comp = newBase(true)
		local called = 0
		embedded:Bind("PostSimulation", function()
			called += 1
		end)
		ext:_advance(0, "PostSimulation")

		comp:Destroy()
		ext:_advance(0, "PostSimulation")
		expect(called).to.equal(1)
	end)

	it("Bind: should bind to component, destructing when called", function()
		local ext, embedded = newBase(true)
		local called = 0
		local destruct = embedded:Bind("PostSimulation", function()
			called += 1
		end)
		ext:_advance(0, "PostSimulation")

		destruct()
		destruct()
		ext:_advance(0, "PostSimulation")
		expect(called).to.equal(1)
	end)

	it("_advance: should advance all internal event names", function()
		local binding = newBase(true)
		local didCall1 = false
		local didCall2 = false

		binding:Connect("PostSimulation", function()
			didCall1 = true
		end)

		binding:Connect("PreRender", function()
			didCall2 = true
		end)

		binding:_advance(0)
		expect(didCall1).to.equal(true)
		expect(didCall2).to.equal(true)
	end)

	it("Connect: should connect to internal event names", function()
		local ext, embedded = newBase(true)
		local calledTimes = 0
		embedded:Bind("PostSimulation", function()
			calledTimes += 1
		end)

		ext:_advance(0, "PostSimulation")
		expect(calledTimes).to.equal(1)
	end)

	it("Connect: should connect to RunService events", function()
		local ext = newBase(false)
		local called = false
		local destruct
		destruct = ext:Connect("PostSimulation", function()
			called = true
		end)
		
		ext.PostSimulation:Wait()
		expect(called).to.equal(true)
		expect(type(destruct)).to.equal("function")
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
		local _, _, c = newBase(true)
		local resumed = false
		coroutine.wrap(function()
			c.Binding:Wait(2)
			resumed = true
		end)()

		expect(resumed).to.equal(false)
		c.man.Binding:_advance(2)
		expect(resumed).to.equal(true)
	end)

	it("Wait: should not count time when paused", function()
		local _, _, c = newBase(true)
		local resumed = false
		coroutine.wrap(function()
			c.Binding:Wait(2)
			resumed = true
		end)()

		c.Binding:Pause()
		c.man.Binding:_advance(4)
		c.man.Binding:_advance(4)
		expect(resumed).to.equal(false)

		c.Binding:Unpause()
		c.man.Binding:_advance(2)
		expect(resumed).to.equal(true)
	end)
end