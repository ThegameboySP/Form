local BaseComponent = require(script.Parent)
local Reloadable = require(script.Reloadable)
local Symbol = require(script.Parent.Parent.Parent.Modules.Symbol)
local NULL = Symbol.named("null")

local new = Instance.new

local function make(ref)
	local c = BaseComponent.new(ref or {}, {})
	c.isTesting = true
	return c
end

local function run(class, ref, config, state)
	local c = class:run(ref or {}, config or {}, state)
	c.isTesting = true
	return c
end

return function()
	describe("State layers", function()
		it("should merge base", function()
			local c = make()
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
			local c = make()
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
			local c = make()
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
			local c = make()
			c.Layers:SetState("second", {
				time = 3;
			})
			c:SetState({
				time = c.add(5);
			})

			expect(c.state.time).to.equal(8)
		end)

		it("should never error when trying to remove non-existent layer", function()
			local c = make()
			expect(function()
				c.Layers:RemoveState("test")
			end).to.never.throw()
		end)

		it("should remove existing layer", function()
			local c = make()
			c:SetState({test1 = false})
			c.Layers:SetState("test", {
				test1 = true;
			})

			expect(c.state.test1).to.equal(true)

			c.Layers:RemoveState("test")

			expect(c.state.test1).to.equal(false)
		end)

		it("should remove a key when it encounters null symbol", function()
			local c = make()
			c:SetState({test = true})

			expect(c.state.test).to.equal(true)
			c:SetState({test = NULL})
			expect(c.state.test).to.equal(nil)
		end)
	end)

	describe("Subscription", function()
		it("should subscribe in a nested path", function()
			local c = make()
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
			local c = make()
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
			local c = make()
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
			local c = make()
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
			local c = make()
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
		it("should register remote events", function()
			local i = new("Folder")
			local c = make(i)
			c.Remote:RegisterEvents("Test")

			expect(function()
				local _ = i.RemoteEvents.BaseComponent.Test
			end).never.to.throw()
		end)

		it("should connect to remote event when it's already registered", function()
			local i = new("Folder")
			local s = make(i)
			s.Remote:RegisterEvents("Test")

			local c = make(i)
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
			local s = make(i)
			local c = make(i)
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
			local s = make(i)
			local c = make(i)
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
			expect(next(c.Layers.layers)).to.be.ok()
		end)

		it("should keep layer order when setting existing layer", function()
			local c = run(Reloadable, {}, {Test = 1}, {Test = 1})
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

		it("mapConfig and mapState should be called on each layer separately", function()
			-- Running calls Reload once...
			local c = run(Reloadable, {}, {ShouldBark = false}, {MappedTimes = 2})
			expect(c.config.Mapped).to.equal(true)
			expect(c.config.MappedTimes).to.equal(1)
			expect(c.state.Mapped).to.equal(true)

			c:Reload()
			expect(c.config.Mapped).to.equal(true)
			expect(c.config.MappedTimes).to.equal(1)
			expect(c.state.Mapped).to.equal(true)
		end)

		it("mapConfig and mapState should not be called if layer has no config", function()
			local c = run(Reloadable, {}, {})
			c:Reload()
			expect(c.config.Mapped).to.equal(nil)
			expect(c.config.IsBarking).to.equal(nil)
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
end