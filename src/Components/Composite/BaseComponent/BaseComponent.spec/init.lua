local BaseComponent = require(script.Parent)
local Reloadable = require(script.Reloadable)
local NULL = require(script.Parent.Parent.Parent.Modules.Symbol).named("null")

local new = Instance.new

local function make(ref)
	local c = BaseComponent.new(ref or {}, {})
	c.isTesting = true
	return c
end

local function start(class, ref, config)
	local c = class:start(ref or {}, config or {})
	c.isTesting = true
	return c
end

return function()
	describe("State layers", function()
		it("should merge base", function()
			local c = make()
			c:setState({
				test = 1;
				test2 = 2
			})

			expect(c.state.test).to.equal(1)
			expect(c.state.test2).to.equal(2)

			c:setState({
				test2 = 1
			})

			expect(c.state.test).to.equal(1)
			expect(c.state.test2).to.equal(1)
		end)

		it("should add state on top of base", function()
			local c = make()
			c:setState({
				test1 = true;
				test2 = c.add(2);
				test3 = 5;
			})

			expect(c.state.test1).to.equal(true)
			expect(c.state.test2).to.equal(2)
			expect(c.state.test3).to.equal(5)

			c:addLayer("two", {
				test2 = c.add(5);
				test3 = c.sub(1);
			})

			expect(c.state.test1).to.equal(true)
			expect(c.state.test2).to.equal(7)
			expect(c.state.test3).to.equal(4)
		end)

		it("should merge existing layer", function()
			local c = make()
			c:mergeLayer("test", {
				test1 = false;
				test2 = true;
			})
			c:mergeLayer("test", {
				test1 = true;
			})

			expect(c.state.test1).to.equal(true)
			expect(c.state.test2).to.equal(true)
		end)

		it("should compound layers with functions", function()
			local c = make()
			c:addLayer("second", {
				time = 3;
			})
			c:setState({
				time = c.add(5);
			})

			expect(c.state.time).to.equal(8)
		end)

		it("should never error when trying to remove non-existent layer", function()
			local c = make()
			expect(function()
				c:removeLayer("test")
			end).to.never.throw()
		end)

		it("should remove existing layer", function()
			local c = make()
			c:setState({test1 = false})
			c:addLayer("test", {
				test1 = true;
			})

			expect(c.state.test1).to.equal(true)

			c:removeLayer("test")

			expect(c.state.test1).to.equal(false)
		end)
	end)

	describe("Subscription", function()
		it("should subscribe in a nested path", function()
			local c = make()
			local value
			c:subscribe("nested.test1", function(v)
				value = v
			end)
			c:setState({
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
			c:setState({
				nested = {
					test1 = false;
				}
			})

			c:subscribeAnd("nested.test1", function(v)
				table.insert(values, v)
			end)
			c:setState({
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
			c:subscribe("test", function(test)
				table.insert(values, test)
			end)

			c:setState({})
			expect(#values).to.equal(0)
			c:setState({test = true})
			expect(#values).to.equal(1)
			c:setState({test = true})
			expect(#values).to.equal(1)
			expect(values[1]).to.equal(true)

			-- Now test for nested items...
			local values2 = {}
			c:subscribe("sub.test2", function(test2)
				table.insert(values2, test2)
			end)

			c:setState({sub = {}})
			expect(#values2).to.equal(0)
			c:setState({sub = {test2 = true}})
			expect(#values2).to.equal(1)
			c:setState({sub = {test2 = true}})
			expect(#values2).to.equal(1)
			expect(values2[1]).to.equal(true)
		end)

		it("should subscribe to tables of state", function()
			local c = make()
			local values = {}
			c:subscribe("nested", function(nested)
				table.insert(values, nested)
			end)

			c:setState({
				nested = {test = true}
			})
			c:setState({
				nested = {test = false}
			})

			expect(#values).to.equal(2)
			expect(values[1].test).to.equal(true)
			expect(values[2].test).to.equal(false)
		end)

		it("should subscribe to deletions of state", function()
			local c = make()
			c:setState({test = true})

			local values = {}
			c:subscribe("test", function(test)
				table.insert(values, test)
			end)

			c:setState({test = NULL})
			expect(#values).to.equal(1)
			expect(values[1]).to.equal(NULL)
		end)
	end)

	describe("Remote", function()
		it("should register remote events", function()
			local i = new("Folder")
			local c = make(i)
			c:registerRemoteEvents("Test")

			expect(function()
				local _ = i.RemoteEvents.BaseComponent.Test
			end).never.to.throw()
		end)

		it("should connect to remote event when it's already registered", function()
			local i = new("Folder")
			local s = make(i)
			s:registerRemoteEvents("Test")

			local c = make(i)
			c.isServer = false

			local values = {}
			c:bindRemoteEvent("Test", function(value)
				table.insert(values, value)
			end)
			s:fireAllClients("Test", "test")

			expect(#values).to.equal(1)
			expect(values[1]).to.equal("test")
		end)

		it("should connect to remote event once it's registered", function()
			local i = new("Folder")
			local s = make(i)
			local c = make(i)
			c.isServer = false

			local values = {}
			c:bindRemoteEvent("Test", function(value)
				table.insert(values, value)
			end)

			s:registerRemoteEvents("Test")
			expect(#values).to.equal(0)
			s:fireAllClients("Test", "test")

			expect(#values).to.equal(1)
			expect(values[1]).to.equal("test")
		end)

		it("should fire server remote event once it's visible", function()
			local i = new("Folder")
			local s = make(i)
			local c = make(i)
			c.isServer = false

			c:fireServer("Test", "test")
			local values = {}
			s:bindRemoteEvent("Test", function(_, value)
				table.insert(values, value)
			end)
			s:registerRemoteEvents("Test")

			expect(#values).to.equal(1)
			expect(values[1]).to.equal("test")
		end)
	end)

	describe("Reloading", function()
		it("should persist state", function()
			local i = new("Folder")
			local c = start(Reloadable, i, {Time = 1})
			
			c:fire("TimeElapsed")

			-- lol
			local called = {}
			c:on("Bark!", function()
				table.insert(called, true)
			end)

			c:reload({ShouldBark = true})

			expect(c.state.State.Name).to.equal("Next")
			expect(c.state.IsBarking).to.equal(true)
			expect(#called).to.equal(1)
		end)
	end)

	describe("Mirror layers", function()
		it("should create a mirror layer, pointing to component", function()
			local c = make()
			c:setState({test = true})

			local layer = c:newMirror()
			expect(layer.Destroy).to.never.equal(c.Destroy)
			expect(function()
				layer:Destroy()
			end).never.to.throw()
			expect(layer:getState().test).to.equal(true)
		end)

		it("should reload the component when provided with config and when destroying", function()
			local c = start(Reloadable)
			expect(c.state.IsBarking).to.equal(false)
			local layer = c:newMirror({ShouldBark = true})
			expect(c.state.IsBarking).to.equal(true)

			layer:Destroy()
			expect(c.state.IsBarking).to.equal(false)
		end)
	end)
end