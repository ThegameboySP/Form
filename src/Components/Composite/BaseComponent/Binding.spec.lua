local RunService = game:GetService("RunService")

local BaseComponent = require(script.Parent)
local TestComponent = BaseComponent:extend("TestComponent", {
	EmbeddedComponents = {"Binding"};
})

local function newBase(isTesting)
	local comp = TestComponent:run({})
	comp.isTesting = isTesting
	return comp.Binding, comp
end

local function newClass(signals)
	local class = BaseComponent:extend("Test", signals)
	class.EmbeddedComponents = {"Binding"}
	local comp = class:run()
	return comp.Binding, comp
end

return function()
	it("Connect: should accept component signal overrides", function()
		local PostSimulation = Instance.new("BindableEvent")
		local binding = newClass({
			PostSimulation = PostSimulation.Event;
		})

		local called = false
		binding:Connect("PostSimulation", function()
			called = true
		end)
		PostSimulation:Fire()

		expect(called).to.equal(true)
	end)
	
	it("Bind: should bind to component, destructing when component destroys", function()
		local binding, comp = newBase(true)
		local called = 0
		binding:Bind("PostSimulation", function()
			called += 1
		end)
		binding:_advance(0, "PostSimulation")

		comp:Destroy()
		binding:_advance(0, "PostSimulation")
		expect(called).to.equal(1)
	end)

	it("Bind: should bind to component, destructing when called", function()
		local binding = newBase(true)
		local called = 0
		local destruct = binding:Bind("PostSimulation", function()
			called += 1
		end)
		binding:_advance(0, "PostSimulation")

		destruct()
		destruct()
		binding:_advance(0, "PostSimulation")
		expect(called).to.equal(1)
	end)

	describe("Unit testing land", function()
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
			local binding = newBase(true)
			local calledTimes = 0
			binding:Bind("PostSimulation", function()
				calledTimes += 1
			end)

			binding:_advance(0, "PostSimulation")
			expect(calledTimes).to.equal(1)
		end)

		it("SpawnNextFrame: should execute callback with args immediately and return a function", function()
			local binding = newBase(true)
			local called = false
			local ret = binding:SpawnNextFrame(function()
				called = true
			end)

			expect(called).to.equal(true)
			expect(type(ret)).to.equal("function")
		end)
	end)

	describe("Play testing land", function()
		if not RunService:IsRunning() then return end

		it("Connect: should connect to RunService events", function()
			local binding = newBase(false)
			local called = false
			local destruct
			destruct = binding:Connect("PostSimulation", function()
				called = true
			end)
			
			RunService.Heartbeat:Wait()
			RunService.Heartbeat:Wait()
			expect(called).to.equal(true)
			expect(type(destruct)).to.equal("function")
		end)

		it("SpawnNextFrame: should wait a frame, then execute callback with args", function()
			local binding = newBase(false)
			local called = false
			local destruct
			destruct = binding:SpawnNextFrame(function()
				called = true
			end)
			
			RunService.Heartbeat:Wait()
			RunService.Heartbeat:Wait()
			expect(called).to.equal(true)
			expect(type(destruct)).to.equal("function")
		end)
	end)
end