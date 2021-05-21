local Maid = require(script.Parent)

local NOOP = function() end
local RET_TRUE = function() return true end

return function()
	describe("Adding tasks", function()
		it("should error when using a reserved id", function()
			expect(function()
				Maid.new().GiveTask = NOOP
			end).to.throw()
		end)

		it("should error when destruct method name does not exist", function()
			local maid = Maid.new()
			expect(function()
				maid:Add({}, "Destroy")
			end).to.throw()
		end)

		it("should error when default destruct method name does not exist", function()
			local maid = Maid.new()
			expect(function()
				maid:Add({})
			end).to.throw()
		end)

		it("should error when giving self as task", function()
			local maid = Maid.new()
			expect(function()
				maid:GiveTask(maid)
			end).to.throw()
		end)

		it("should error if adding anything but a function, Instance, table, or RBXScriptConnection", function()
			local maid = Maid.new()

			expect(function()
				maid:GiveTask(false)
			end).to.throw()

			expect(function()
				maid:GiveTask(Instance.new("Folder").ChildAdded)
			end).to.throw()
			
			expect(function()
				maid:GiveTask("test")
			end).to.throw()

			expect(function()
				maid:GiveTask(2)
			end).to.throw()
		end)

		it("no id argument: should add task with internal numerical id", function()
			local maid = Maid.new()
			expect( type(maid:GiveTask(NOOP)) ).to.equal("number")
		end)

		it("id argument: should replace existing task if different", function()
			local maid = Maid.new()
			local didCall = false
			maid:GiveTask(function() didCall = true end, nil, "test")
			expect(didCall).to.equal(false)
			maid:GiveTask(NOOP, nil, "test")
			
			local didCall2 = false
			maid.test = function() didCall2 = true end
			expect(didCall2).to.equal(false)
			maid.test = NOOP

			expect(didCall).to.equal(true)
			expect(didCall2).to.equal(true)
		end)

		it("id argument: should never replace existing task if it's the same task", function()
			local maid = Maid.new()
			local didCall = false
			local function func()
				didCall = true
			end

			maid:GiveTask(func, nil, "test")
			maid:GiveTask(func, nil, "test")
			
			maid.test = func
			maid.test = func

			expect(didCall).to.equal(false)
		end)

		it("destructor argument: should add object or userdata with destruct method name", function()
			local maid = Maid.new()
			rawset(maid, "Destroy", NOOP)

			local subMaid = Maid.new()
			local didClean = false
			subMaid:GiveTask(function()
				didClean = true
			end)

			local instance = Instance.new("Folder")
			instance.Parent = Instance.new("Folder")

			maid:Remove( maid:GiveTask(subMaid, "DoCleaning") )
			maid:Remove( maid:GiveTask(instance, "Destroy") )
			expect(didClean).to.equal(true)
			expect(instance.Parent).to.equal(nil)
		end)

		it("default: should accept functions", function()
			local maid = Maid.new()
			local id = maid:GiveTask(RET_TRUE)
			expect( maid:Remove(id) ).to.equal(true)
		end)

		it("default: should accept tables", function()
			local maid = Maid.new()
			expect( maid:Add(Maid.new()) ).to.be.ok()
		end)

		it("default: should accept Instances", function()
			local maid = Maid.new()
			local i = Instance.new("Folder")
			i.Parent = Instance.new("Folder")

			maid:Remove( maid:GiveTask(i) )
			expect(i.Parent).to.equal(nil)
		end)

		it("default: should accept RBXScriptConnections", function()
			local maid = Maid.new()
			local con = Instance.new("Folder").ChildAdded:Connect(NOOP)

			maid:Remove( maid:GiveTask(con) )
			expect(con.Connected).to.equal(false)
		end)

		it("AddTask: should invoke :GiveTask, then return the task", function()
			local maid = Maid.new()
			local i = Instance.new("Folder")
			expect(maid:Add(i)).to.equal(i)
		end)

		it("GiveTasks: should add tasks by key name then return self and ids", function()
			local maid = Maid.new()
			local ret, ids = maid:GiveTasks({test = NOOP})

			expect(maid.test).to.equal(NOOP)
			expect(ret).to.equal(maid)
			expect(ids.test).to.equal(NOOP)
		end)

		it("GiveTasks: should add tasks in array then return self and ids", function()
			local maid = Maid.new()
			local ret, ids = maid:GiveTasks({NOOP})

			expect(maid[1]).to.equal(NOOP)
			expect(ret).to.equal(maid)
			expect(ids[1]).to.equal(NOOP)
		end)

		it("dot notation: should access tasks", function()
			local maid = Maid.new()
			maid.test = NOOP
			maid:GiveTask(NOOP, nil, "test2")

			expect(maid.test).to.equal(NOOP)
			expect(maid.test2).to.equal(NOOP)
		end)
	end)

	describe("Removing tasks", function()
		it("should allow tasks to be added and then cleaned during :Destroy()", function()
			local maid = Maid.new()

			local didCall = false
			maid:GiveTask(function()
				maid:GiveTask(function()
					didCall = true
				end)
			end)
			expect(didCall).to.equal(false)

			maid:Destroy()
			expect(didCall).to.equal(true)
		end)

		it("should transfer parameters of :DoCleaning to a function being invoked", function()
			local maid = Maid.new()
			local t1
			maid:Add(function(test)
				t1 = test
			end)

			local tbl = {}
			local t2
			function tbl:Destroy(test)
				t2 = test
			end
			maid:Add(tbl)

			maid:DoCleaning(true)
			expect(t1).to.equal(true)
			expect(t2).to.equal(true)
		end)

		it("should return the result of a function being :Remove'd", function()
			local maid = Maid.new()
			expect( maid:Remove(maid:GiveTask(RET_TRUE)) ).to.equal(true)
		end)

		it("should transfer the parameters of :Remove to a function being invoked", function()
			local maid = Maid.new()
			local parameter
			expect(maid:Remove(maid:GiveTask(function(p1)
				parameter = p1
			end), true))

			expect(parameter).to.equal(true)
		end)

		it("dot notation: should remove an existing task when setting it to nil", function()
			local maid = Maid.new()
			local didCall = false
			maid.test = function()
				didCall = true
			end
			expect(didCall).to.equal(false)

			maid.test = nil
			expect(didCall).to.equal(true)
		end)

		it("dot notation: should replace an existing task", function()
			local maid = Maid.new()
			local didCall = false
			maid.test = function()
				didCall = true
			end
			expect(didCall).to.equal(false)

			local didCall2 = false
			maid.test = function()
				didCall2 = true
			end
			expect(didCall2).to.equal(false)

			maid.test = nil
			expect(didCall).to.equal(true)
			expect(didCall2).to.equal(true)
		end)
	end)
end