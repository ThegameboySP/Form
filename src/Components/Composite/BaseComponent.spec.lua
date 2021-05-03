local BaseComponent = require(script.Parent.BaseComponent)

local new = Instance.new

local function make(ref)
	local c = BaseComponent.new(ref or {}, {})
	c.isTesting = true
	return c
end

return function()
	describe("State layers", function()
		it("should add state on top of base", function()
			local c = make()
			c:setState({
				test1 = false;
				test2 = true;
			})
			c:addLayer("test", {
				test1 = true;
			})

			expect(c.state.test1).to.equal(true)
			expect(c.state.test2).to.equal(true)
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

		it("should never error when trying to remove non-existent layer", function()
			local c = make()
			expect(function()
				c:removeLayer("test")
			end).to.never.throw()
		end)

		it("should remove existing layer", function()
			local c = make()
			c:addLayer("test", {
				test1 = true;
			})

			expect(c.state.test1).to.equal(true)

			c:removeLayer("test")

			expect(c.state.test1).to.equal(nil)
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
			s:fireAllClients("Test", "test")

			expect(#values).to.equal(1)
			expect(values[1]).to.equal("test")
		end)
	end)
end