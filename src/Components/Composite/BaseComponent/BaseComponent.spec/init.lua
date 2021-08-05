local BaseComponent = require(script.Parent)
local Reloadable = require(script.Reloadable)
local Symbol = require(script.Parent.Parent.Parent.Modules.Symbol)
local t = require(script.Parent.Parent.Parent.Modules.t)
local ComponentsUtils = require(script.Parent.Parent.Parent.Shared.ComponentsUtils)
local spy = require(script.Parent.Parent.Parent.Testing.spy)
local NULL = Symbol.named("null")

local new = Instance.new

local TestComponent = BaseComponent:extend("TestComponent")

local function run(class, ref, config, layers)
	if layers then
		local c = class:run(ref or {}, {
			config = config,
			layers = {[Symbol.named("base")] = layers}
		})
		
		c.isTesting = true
		return c
	else
		local c = class:run(ref or {}, {config = config or {}})
		c.isTesting = true
		return c
	end
end

return function()
	describe("Lifecycle methods", function()
		it("run: should invoke :PreInit, :Init, and :Main in order, once", function()
			local ExpectationComponent = BaseComponent:extend("Test")

			local t1 = {}
			ExpectationComponent.PreInit = spy(t1)
			local t2 = {}
			ExpectationComponent.Init = spy(t2)
			local t3 = {}
			ExpectationComponent.Main = spy(t3)

			local comp = ExpectationComponent:run()
			expect(t1.Count).to.equal(1)
			expect(t1.Params[1][1]).to.equal(comp)
			expect(t2.Count).to.equal(1)
			expect(t2.Params[1][1]).to.equal(comp)
			expect(t3.Count).to.equal(1)
			expect(t3.Params[1][1]).to.equal(comp)
		end)
	end)

	describe("State layers", function()
		it("should merge base", function()
			local c = run(TestComponent)

			c:SetState({
				test = 1;
				test2 = 2
			})

			expect(c.state.test).to.equal(1)
			expect(c.state.test2).to.equal(2)

			c:SetState({
				test2 = 1
			})

			expect(c.state.test).to.equal(1)
			expect(c.state.test2).to.equal(1)
		end)

		it("should add state on top of base", function()
			local c = run(TestComponent)
			c:SetState({
				test1 = true;
				test2 = c.add(2);
				test3 = 5;
			})

			expect(c.state.test1).to.equal(true)
			expect(c.state.test2).to.equal(2)
			expect(c.state.test3).to.equal(5)

			c.Layers:SetState("two", {
				test2 = c.add(5);
				test3 = c.sub(1);
			})

			expect(c.state.test1).to.equal(true)
			expect(c.state.test2).to.equal(7)
			expect(c.state.test3).to.equal(4)
		end)

		it("should merge existing layer", function()
			local c = run(TestComponent)
			c.Layers:MergeState("test", {
				test1 = false;
				test2 = true;
			})
			c.Layers:MergeState("test", {
				test1 = true;
			})

			expect(c.state.test1).to.equal(true)
			expect(c.state.test2).to.equal(true)
		end)

		it("should compound layers with functions", function()
			local c = run(TestComponent)
			c.Layers:SetState("second", {
				time = 3;
			})
			c:SetState({
				time = c.add(5);
			})

			expect(c.state.time).to.equal(8)
		end)

		it("should never error when trying to remove non-existent layer", function()
			local c = run(TestComponent)
			expect(function()
				c.Layers:RemoveState("test")
			end).to.never.throw()
		end)

		it("should remove existing layer", function()
			local c = run(TestComponent)
			c:SetState({test1 = false})
			c.Layers:SetState("test", {
				test1 = true;
			})

			expect(c.state.test1).to.equal(true)

			c.Layers:RemoveState("test")

			expect(c.state.test1).to.equal(false)
		end)

		it("should remove a key when it encounters null symbol", function()
			local c = run(TestComponent)
			c:SetState({test = true})

			expect(c.state.test).to.equal(true)
			c:SetState({test = NULL})
			expect(c.state.test).to.equal(nil)
		end)
	end)

	describe("Subscription", function()
		it("should subscribe in a nested path", function()
			local c = run(TestComponent)
			local value
			c:Subscribe("nested.test1", function(v)
				value = v
			end)
			c:SetState({
				nested = {
					test1 = true;
				}
			})

			c:Destroy()
			expect(value).to.equal(true)
		end)

		it("should subscribe and call by current value of nested path", function()
			local c = run(TestComponent)
			local values = {}
			c:SetState({
				nested = {
					test1 = false;
				}
			})

			c:SubscribeAnd("nested.test1", function(v)
				table.insert(values, v)
			end)
			c:SetState({
				nested = {
					test1 = true;
				}
			})

			c:Destroy()
			expect(#values).to.equal(2)
			expect(values[1]).to.equal(false)
			expect(values[2]).to.equal(true)
		end)

		it("should never fire if there was no change", function()
			local c = run(TestComponent)
			local values = {}
			c:Subscribe("test", function(test)
				table.insert(values, test)
			end)

			c:SetState({})
			expect(#values).to.equal(0)
			c:SetState({test = true})
			expect(#values).to.equal(1)
			c:SetState({test = true})
			expect(#values).to.equal(1)
			expect(values[1]).to.equal(true)

			-- Now test for nested items...
			local values2 = {}
			c:Subscribe("sub.test2", function(test2)
				table.insert(values2, test2)
			end)

			c:SetState({sub = {}})
			expect(#values2).to.equal(0)
			c:SetState({sub = {test2 = true}})
			expect(#values2).to.equal(1)
			c:SetState({sub = {test2 = true}})
			expect(#values2).to.equal(1)
			expect(values2[1]).to.equal(true)
		end)

		it("should subscribe to tables of state", function()
			local c = run(TestComponent)
			local values = {}
			c:Subscribe("nested", function(nested)
				table.insert(values, nested)
			end)

			c:SetState({
				nested = {test = true}
			})
			c:SetState({
				nested = {test = false}
			})

			expect(#values).to.equal(2)
			expect(values[1].test).to.equal(true)
			expect(values[2].test).to.equal(false)
		end)

		it("should subscribe to deletions of state", function()
			local c = run(TestComponent)
			c:SetState({test = true})

			local values = {}
			c:Subscribe("test", function(test)
				table.insert(values, test)
			end)

			c:SetState({test = NULL})
			expect(#values).to.equal(1)
			expect(values[1]).to.equal(NULL)
		end)
	end)

	describe("Remote", function()
		local RemoteComponent = BaseComponent:extend("RemoteComponent", {
			EmbeddedComponents = {"Remote"}
		})

		it("should register remote events", function()
			local i = new("Folder")
			local c = run(RemoteComponent, i)
			c.Remote:RegisterEvents("Test")

			expect(function()
				local _ = i.RemoteEvents.RemoteComponent.Test
			end).never.to.throw()
		end)

		it("should connect to remote event when it's already registered", function()
			local i = new("Folder")
			local s = run(RemoteComponent, i)
			s.Remote:RegisterEvents("Test")

			local c = run(RemoteComponent, i)
			c.isServer = false

			local values = {}
			c.Remote:BindEvent("Test", function(value)
				table.insert(values, value)
			end)
			s.Remote:FireAllClients("Test", "test")

			expect(#values).to.equal(1)
			expect(values[1]).to.equal("test")
		end)

		it("should connect to remote event once it's registered", function()
			local i = new("Folder")
			local s = run(RemoteComponent, i)
			local c = run(RemoteComponent, i)
			c.isServer = false

			local values = {}
			c.Remote:BindEvent("Test", function(value)
				table.insert(values, value)
			end)

			s.Remote:RegisterEvents("Test")
			expect(#values).to.equal(0)
			s.Remote:FireAllClients("Test", "test")

			expect(#values).to.equal(1)
			expect(values[1]).to.equal("test")
		end)

		it("should fire server remote event once it's visible", function()
			local i = new("Folder")
			local s = run(RemoteComponent, i)
			local c = run(RemoteComponent, i)
			c.isServer = false

			c.Remote:FireServer("Test", "test")
			local values = {}
			s.Remote:BindEvent("Test", function(_, value)
				table.insert(values, value)
			end)
			s.Remote:RegisterEvents("Test")

			expect(#values).to.equal(1)
			expect(values[1]).to.equal("test")
		end)
	end)

	describe("Reloading", function()
		it("should persist state", function()
			local i = new("Folder")
			local c = run(Reloadable, i, {Time = 1})
			
			c:Fire("TimeElapsed")

			local called = {}
			c:On("Bark!", function()
				table.insert(called, true)
			end)

			c:SetConfig({ShouldBark = true})

			expect(c.state.State.Name).to.equal("Next")
			expect(c.state.IsBarking).to.equal(true)
			expect(#called).to.equal(1)
		end)
	end)

	describe("Layers", function()
		it(":run() should create base layer", function()
			local c = run(Reloadable)
			expect(next(c.Layers:get())).to.be.ok()
		end)

		it("should keep layer order when setting existing layer", function()
			local c = run(Reloadable, {}, nil, {config = {Test = 1}, state = {Test = 1}})
			expect(c.config.Test).to.equal(1)
			expect(c.state.Test).to.equal(1)

			c.Layers:Set("layer2", {Test = 2}, {Test = 2})
			expect(c.config.Test).to.equal(2)
			expect(c.state.Test).to.equal(2)

			c:SetLayer({Test = 3}, {Test = 3})
			expect(c.config.Test).to.equal(2)
			expect(c.state.Test).to.equal(2)

			c.Layers:Set("layer2", {Test = 4}, {Test = 4})
			expect(c.config.Test).to.equal(4)
			expect(c.state.Test).to.equal(4)
		end)

		it("mapConfig and mapState should not be called if layer has no config", function()
			local c = Reloadable:run({}, nil)
			expect(c.config.Mapped).to.equal(nil)
			expect(c.state.IsBarking).to.equal(nil)
		end)

		it("should destroy component after all layers are destroyed", function()
			local c = run(Reloadable)
			c.Layers:SetState("layer2", {blah = true})
			expect(c.isDestroyed).to.equal(false)

			c.Layers:Remove("layer2")
			expect(c.isDestroyed).to.equal(false)
			c.Layers:Remove(Symbol.named("base"))
			expect(c.isDestroyed).to.equal(true)
		end)

		it("should merge config and state when destroying and setting layers", function()
			local c = run(Reloadable, {}, {ShouldBark = false})
			expect(c.state.IsBarking).to.equal(false)
			expect(c.config.ShouldBark).to.equal(false)

			c.Layers:SetConfig("layer2", {ShouldBark = true})
			expect(c.state.IsBarking).to.equal(true)
			expect(c.config.ShouldBark).to.equal(true)

			c.Layers:Remove("layer2")
			expect(c.state.IsBarking).to.equal(false)
			expect(c.config.ShouldBark).to.equal(false)

			c:SetConfig({ShouldBark = false})
			expect(c.state.IsBarking).to.equal(false)
			expect(c.config.ShouldBark).to.equal(false)
		end)
	end)

	describe("Pause", function()
		local PauseComponent = BaseComponent:extend("PauseComponent")
		it("should pause and unpause", function()
			local c = run(PauseComponent)
			local p = c.Pause

			expect(p:IsPaused()).to.equal(false)
			p:Pause()
			p:Pause()
			expect(p:IsPaused()).to.equal(true)
			p:Unpause()
			p:Unpause()
			expect(p:IsPaused()).to.equal(false)
		end)

		it("should only fire Paused and Unpaused when there was a change", function()
			local c = run(PauseComponent)
			local p = c.Pause
			local tbl = {}
			local func = spy(tbl)

			c:On("Paused", func)
			c:On("Unpaused", func)

			p:Pause()
			p:Pause()
			expect(tbl.Count).to.equal(1)
			expect(tbl.Params[1][1]).to.equal(nil)

			p:Unpause()
			p:Unpause()
			expect(tbl.Count).to.equal(2)
			expect(tbl.Params[2][1]).to.equal(nil)
		end)

		it("should suppress all Wrap'ed events when paused", function()
			local c = run(PauseComponent)
			local p = c.Pause
			local tbl = {}
			local func = p:Wrap(spy(tbl))

			p:Pause()
			c:On("Test", func)
			c:OnAny(func)
			c:Fire("Test")

			local bindable = new("BindableEvent")
			bindable.Event:Connect(func)
			bindable:Fire()

			expect(tbl.Count).to.equal(0)
		end)
	end)

	describe("Sleep", function()
		it("should yield the thread until the given time", function()
			local c = run(TestComponent)
			local resumed = false
			coroutine.wrap(function()
				c.sleep(2)
				resumed = true
			end)()

			expect(resumed).to.equal(false)
			c.Binding:_advance(2)
			expect(resumed).to.equal(true)
		end)

		it("should not count time when paused", function()
			local c = run(TestComponent)
			local resumed = false
			coroutine.wrap(function()
				c.sleep(2)
				resumed = true
			end)()

			c.Pause:Pause()
			c.Binding:_advance(4)
			c.Binding:_advance(4)
			expect(resumed).to.equal(false)

			c.Pause:Unpause()
			c.Binding:_advance(2)
			expect(resumed).to.equal(true)
		end)
	end)

	describe("Interfaces", function()
		it("IConfig: should error on bad config layer and bad final config, while canceling the transaction", function()
			local ExpectationComponent = BaseComponent:extend("Test", {
				IConfig = t.strictInterface({test = function(item)
					return item == 1
				end})
			})

			-- On initialization:
			expect(function()
				run(ExpectationComponent, {}, {})
			end).to.throw()

			local c = run(ExpectationComponent, {}, {test = 1})
			c.Layers:Set("layer2")
			local layers = ComponentsUtils.deepCopy(c.Layers:get())

			-- Change layer:
			expect(function()
				c.Layers:SetConfig("layer2", {test = "blah"})
			end).to.throw()

			expect(ComponentsUtils.deepCompare(layers, c.Layers:get())).to.equal(true)

			expect(function()
				c.Layers:SetConfig("layer2", {test = 1})
			end).to.never.throw()
		end)

		it("IState: should error on bad state layer and bad final state, while canceling the transaction", function()
			local ExpectationComponent = BaseComponent:extend("Test", {
				IState = t.strictInterface({test = function(item)
					return item == 1
				end})
			})

			-- On initialization:
			expect(function()
				run(ExpectationComponent, {}, {})
			end).to.throw()

			local c = run(ExpectationComponent, {}, nil, {state = {test = 1}})
			c.Layers:Set("layer2")
			local layers = ComponentsUtils.deepCopy(c.Layers:get())

			-- Change layer:
			expect(function()
				c.Layers:SetState("layer2", {test = "blah"})
			end).to.throw()

			-- Final layer:
			expect(function()
				c.Layers:SetState("layer2", {test = c.add(1)})
			end).to.throw()

			expect(ComponentsUtils.deepCompare(layers, c.Layers:get())).to.equal(true)

			expect(function()
				c.Layers:SetState("layer2", {test = 1})
			end).to.never.throw()
		end)

		it("IRef: should error on bad reference", function()
			local ExpectationComponent = BaseComponent:extend("Test", {
				IRef = t.instanceIsA("Folder")
			})

			expect(function()
				run(ExpectationComponent, {})
			end).to.throw()

			expect(function()
				run(ExpectationComponent, new("Folder"))
			end).to.never.throw()
		end)
	end)

	describe("Subcomponents", function()
		local ExpectationComponent = BaseComponent:extend("Test", {
			EmbeddedComponents = {"Layers"}
		})

		it("should add a component to itself", function()
			local c = run(TestComponent)
			local subComp, id = c:GetOrAddComponent(ExpectationComponent, {config = {key1 = true}})
			expect(c.added[ExpectationComponent]).to.equal(subComp)
			expect(subComp:GetClass()).to.equal(ExpectationComponent)

			expect(subComp.isDestroyed).to.equal(false)
			subComp.Layers:Remove(id)
			expect(subComp.isDestroyed).to.equal(true)
			expect(c.added[ExpectationComponent]).to.equal(nil)
		end)

		it("should remove a component from itself", function()
			local c = run(TestComponent)
			local subComp = c:GetOrAddComponent(ExpectationComponent, {config = {key1 = true}})
			expect(c.added[ExpectationComponent]).to.equal(subComp)

			c:RemoveComponent(ExpectationComponent)
			expect(c.added[ExpectationComponent]).to.equal(nil)
		end)
	end)
end