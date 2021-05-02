local BaseComponent = require(script.Parent.BaseComponent)

return function()
	describe("State layers", function()
		it("should add state on top of base", function()
			local c = BaseComponent.new({})
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
			local c = BaseComponent.new({})
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
			local c = BaseComponent.new({})
			expect(function()
				c:removeLayer("test")
			end).to.never.throw()
		end)

		it("should remove existing layer", function()
			local c = BaseComponent.new({})
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
			local c = BaseComponent.new({})
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
			local c = BaseComponent.new({})
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
			expect(values[1]).to.equal(false)
			expect(values[2]).to.equal(true)
		end)
	end)
end