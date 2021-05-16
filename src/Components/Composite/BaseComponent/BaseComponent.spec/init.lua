local BaseComponent = require(script.Parent)
local Reloadable = require(script.Reloadable)
local NULL = require(script.Parent.Parent.Parent.Modules.Symbol).named("null")

local new = Instance.new

local function make(ref)
	local c = BaseComponent.new(ref or {}, {})
	c.isTesting = true
	return c
end

local function run(class, ref, config)
	local c = class:run(ref or {}, config or {})
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

			c:AddLayer("two", {
				test2 = c.add(5);
				test3 = c.sub(1);
			})

			expect(c.state.test1).to.equal(true)
			expect(c.state.test2).to.equal(7)
			expect(c.state.test3).to.equal(4)
		end)

		it("should merge existing layer", function()
			local c = make()
			c:MergeLayer("test", {
				test1 = false;
				test2 = true;
			})
			c:MergeLayer("test", {
				test1 = true;
			})

			expect(c.state.test1).to.equal(true)
			expect(c.state.test2).to.equal(true)
		end)

		it("should compound layers with functions", function()
			local c = make()
			c:AddLayer("second", {
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
				c:RemoveLayer("test")
			end).to.never.throw()
		end)

		it("should remove existing layer", function()
			local c = make()
			c:SetState({test1 = false})
			c:AddLayer("test", {
				test1 = true;
			})

			expect(c.state.test1).to.equal(true)

			c:RemoveLayer("test")

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
			c:RegisterRemoteEvents("Test")

			expect(function()
				local _ = i.RemoteEvents.BaseComponent.Test
			end).never.to.throw()
		end)

		it("should connect to remote event when it's already registered", function()
			local i = new("Folder")
			local s = make(i)
			s:RegisterRemoteEvents("Test")

			local c = make(i)
			c.isServer = false

			local values = {}
			c:BindRemoteEvent("Test", function(value)
				table.insert(values, value)
			end)
			s:FireAllClients("Test", "test")

			expect(#values).to.equal(1)
			expect(values[1]).to.equal("test")
		end)

		it("should connect to remote event once it's registered", function()
			local i = new("Folder")
			local s = make(i)
			local c = make(i)
			c.isServer = false

			local values = {}
			c:BindRemoteEvent("Test", function(value)
				table.insert(values, value)
			end)

			s:RegisterRemoteEvents("Test")
			expect(#values).to.equal(0)
			s:FireAllClients("Test", "test")

			expect(#values).to.equal(1)
			expect(values[1]).to.equal("test")
		end)

		it("should fire server remote event once it's visible", function()
			local i = new("Folder")
			local s = make(i)
			local c = make(i)
			c.isServer = false

			c:FireServer("Test", "test")
			local values = {}
			s:BindRemoteEvent("Test", function(_, value)
				table.insert(values, value)
			end)
			s:RegisterRemoteEvents("Test")

			expect(#values).to.equal(1)
			expect(values[1]).to.equal("test")
		end)
	end)

	describe("Reloading", function()
		it("should persist state", function()
			local i = new("Folder")
			local c = run(Reloadable, i, {Time = 1})
			
			c:Fire("TimeElapsed")

			-- lol
			local called = {}
			c:On("Bark!", function()
				table.insert(called, true)
			end)

			c:Reload({ShouldBark = true})

			expect(c.state.State.Name).to.equal("Next")
			expect(c.state.IsBarking).to.equal(true)
			expect(#called).to.equal(1)
		end)
	end)

	describe("Mirror layers", function()
		it("should create a mirror layer, pointing to component", function()
			local c = make()
			c:SetState({test = true})

			local layer = c:NewMirror()
			expect(layer.Destroy).to.equal(c.Destroy)
			expect(type(layer.DestroyMirror)).to.equal("function")
			expect(function()
				layer:DestroyMirror()
			end).never.to.throw()
			expect(layer:GetState().test).to.equal(true)
		end)

		it(":run() should return a mirror layer", function()
			local c = run(Reloadable)
			expect(c.isMirror).to.equal(true)
		end)

		it("mapConfig and mapState should be called on each layer separately", function()
			local c = run(Reloadable, {}, {ShouldBark = false})
			expect(c.config.ShouldBark).to.equal(false)
			expect(c.config.Mapped).to.equal(true)
			expect(c.config.IsBarking).to.equal(false)
			
			c:NewMirror({ShouldBark = true})
			expect(c.config.ShouldBark).to.equal(true)
			expect(c.config.Mapped).to.equal(true)
			expect(c.config.IsBarking).to.equal(true)
		end)

		it("mapConfig and mapState should not be called if mirror has no config", function()
			local c = run(Reloadable, {}, {})
			expect(c.config.Mapped).to.equal(nil)
			expect(c.config.IsBarking).to.equal(nil)
		end)

		it("should destroy component after all mirrors are destroyed", function()
			local c = run(Reloadable)
			local m = c:NewMirror()
			expect(m._source.isDestroyed).to.equal(false)

			m:DestroyMirror()
			expect(m._source.isDestroyed).to.equal(false)
			c:DestroyMirror()
			expect(m._source.isDestroyed).to.equal(true)
		end)

		it("should merge config and state when destroying and reloading mirrors", function()
			local c = run(Reloadable, {}, {ShouldBark = false})
			expect(c.state.IsBarking).to.equal(false)
			expect(c.config.ShouldBark).to.equal(false)

			local layer = c:NewMirror({ShouldBark = true})
			expect(c.state.IsBarking).to.equal(true)
			expect(c.config.ShouldBark).to.equal(true)

			layer:Reload({ShouldBark = false})
			expect(c.state.IsBarking).to.equal(false)
			expect(c.config.ShouldBark).to.equal(false)

			layer:DestroyMirror()
			expect(c.state.IsBarking).to.equal(false)
			expect(c.config.ShouldBark).to.equal(false)

			c:Reload({ShouldBark = true})
			expect(c.state.IsBarking).to.equal(true)
			expect(c.config.ShouldBark).to.equal(true)
		end)
	end)
end