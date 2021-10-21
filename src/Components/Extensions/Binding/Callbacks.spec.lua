local Callbacks = require(script.Parent.Callbacks)

return function()
	it("should validate parameters", function()
		local callbacks = Callbacks.new()
		expect(function()
			callbacks:ConnectAtPriority("test", function() end)
		end).to.throw()
		
		expect(function()
			callbacks:ConnectAtPriority(1, {test = true})
		end).to.throw()

		expect(function()
			callbacks:ConnectAtPriority(1, setmetatable({}, {__call = function() end}))
		end).to.never.throw()
	end)

	it("should place a connection at beginning of list and disconnect", function()
		local callbacks = Callbacks.new()
		local called = false
		callbacks:ConnectAtPriority(1, function()
			called = true
		end):Disconnect()
		
		callbacks:Fire()
		expect(called).to.equal(false)
	end)

	it("should place a connection before a previously placed one and disconnect", function()
		local callbacks = Callbacks.new()
		local called1 = false
		callbacks:ConnectAtPriority(0, function()
			called1 = true
		end)

		local called2 = false
		local con = callbacks:ConnectAtPriority(1, function()
			called2 = true
		end)

		local called3 = false
		callbacks:ConnectAtPriority(2, function()
			called3 = true
		end)

		con:Disconnect()

		callbacks:Fire()
		expect(called1).to.equal(true)
		expect(called2).to.equal(false)
		expect(called3).to.equal(true)
	end)

	it("should place a connection at the end of the list and disconnect", function()
		local callbacks = Callbacks.new()
		local called1 = false
		callbacks:ConnectAtPriority(1, function()
			called1 = true
		end)

		local called2 = false
		callbacks:ConnectAtPriority(2, function()
			called2 = true
		end):Disconnect()

		callbacks:Fire()
		expect(called1).to.equal(true)
		expect(called2).to.equal(false)
	end)

	it("should call connections in order", function()
		local callbacks = Callbacks.new()

		local called = {}
		for i=1, 4 do
			callbacks:ConnectAtPriority(4 - i, function()
				table.insert(called, i)
			end)
		end

		callbacks:Fire()
		for index, i in ipairs(called) do
			expect(i).to.equal(index)
		end
	end)
end