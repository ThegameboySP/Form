local Tracker = require(script.Parent)

return function()
	describe("Tracker", function()
		it("should fully add and remove an object internally", function()
			local tracker = Tracker.new()
			local tbl = {}
			local con = {test = true}

			tracker:Add(tbl, con)

			expect(tracker:GetAdded()[1]).to.equal(tbl)
			expect(tracker:GetInstanceContext(tbl).test).to.equal(true)
			
			tracker:Remove(tbl)

			expect(tracker:GetAdded()[1]).to.equal(nil)
			expect(tracker:GetInstanceContext(tbl)).to.equal(nil)
		end)

		it("should fire connections appropriately", function()
			local tracker = Tracker.new()
			local tbl = {}

			local firedAdded = false
			tracker.Added:Connect(function(item)
				expect(item).to.equal(tbl)
				firedAdded = true
			end)

			local firedRemoved = false
			tracker.Removed:Connect(function(item)
				expect(item).to.equal(tbl)
				firedRemoved = true
			end)

			tracker:Add(tbl)
			tracker:Remove(tbl)

			expect(firedAdded).to.equal(true)
			expect(firedRemoved).to.equal(true)

			tracker:Destroy()
		end)

		it("OnAdded: should fire .Added and run handler for cached items and context", function()
			local tracker = Tracker.new()
			local tbl = {}
			local tbl2 = {}

			local con1 = {one = true}
			local con2 = {two = true}

			tracker:Add(tbl, con1)
			
			local called = {}
			tracker:OnAdded(function(item, con)
				table.insert(called, {item, con})
			end)

			tracker:Add(tbl2, con2)

			expect(#called).to.equal(2)
			expect(tracker:GetInstanceContext(tbl).one).to.equal(true)
			expect(tracker:GetInstanceContext(tbl2).two).to.equal(true)

			tracker:Destroy()
		end)

		it("should get all parent entries", function()
			local parentTracker = Tracker.new()
			local tracker = Tracker.new()
			local tbl = {}

			parentTracker:Add(tbl)
			tracker:SetSource(parentTracker)
			expect(tracker:GetAdded()[1]).to.equal(tbl)

			parentTracker:Remove(tbl)
			expect(tracker:GetAdded()[1]).to.equal(nil)
		end)

		it("SetAddWrapper: should pass item, maid, and add function", function()
			local parentTracker = Tracker.new()
			local tracker = Tracker.new()
			local tbl = {}

			local called = {}
			tracker:SetAddWrapper(function(item, maid, add)
				table.insert(called, {item, maid, add})
				add(item)
			end)

			tracker:SetSource(parentTracker)
			parentTracker:Add(tbl)

			expect(typeof(called[1][1])).to.equal("table")
			expect(typeof(called[1][2])).to.equal("table")
			expect(typeof(called[1][3])).to.equal("function")
		end)

		it("should remove all sub items when source removes an item", function()
			local parentTracker = Tracker.new()
			local tracker = Tracker.new()
			local tbl = {sub1 = {}}

			local didClean = false
			tracker:SetAddWrapper(function(item, maid, add)
				maid:GiveTask(function()
					didClean = true
				end)
				add(item.sub1)
			end)

			tracker:SetSource(parentTracker)
			parentTracker:Add(tbl)
			expect(tracker:IsAdded(tbl.sub1)).to.equal(true)

			parentTracker:Remove(tbl)

			expect(didClean).to.equal(true)
			expect(#tracker:GetAdded()).to.equal(0)
		end)

		it("context: should set instance context with :SetInstanceMap", function()
			local tracker = Tracker.new()
			local tbl = {}

			tracker:SetInstanceMap(function(item, context)
				context.blah = true
				return item, context
			end)

			tracker:Add(tbl)

			local context = tracker:GetInstanceContext(tbl)
			expect(context.blah).to.equal(true)
		end)

		it("context: should transfer parent context down to descendant tracker's instances", function()
			local parentTracker = Tracker.new()
			local tracker = Tracker.new()
			local tbl = {sub1 = {}}

			tracker:SetAddWrapper(function(item, _, add)
				add(item.sub1)
			end)

			tracker:SetSource(parentTracker)
			parentTracker:Add(tbl, {parent = true})

			local subContext = tracker:GetInstanceContext(tbl.sub1)
			expect(subContext.parent).to.equal(true)
		end)

		it("context: should never allow child trackers to mutate parent's context", function()
			local parentTracker = Tracker.new()
			local tracker = Tracker.new()
			local tbl = {sub1 = {}}

			tracker:SetAddWrapper(function(item, _, add)
				add(item.sub1)
			end):SetInstanceMap(function(item, context)
				context.blah = true
				return item, context
			end)

			tracker:SetSource(parentTracker)
			parentTracker:Add(tbl, {parent = true})

			local subContext = tracker:GetInstanceContext(tbl.sub1)
			expect(subContext.blah).to.equal(true)
			expect(subContext.parent).to.equal(true)
			expect(parentTracker:GetInstanceContext(tbl).blah).to.equal(nil)
		end)
		-- test context
	end)
end