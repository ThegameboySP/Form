local t = require(script.Parent.Parent.Parent.Modules.t)
local DataEmbedded = require(script.Parent.DataEmbedded)
local Ops = require(script.Parent.Ops)

return function()
	local MockExtension = {pending = {}}
	
	it("should use 1 layer", function()
		local data = DataEmbedded.new(MockExtension)
		data:InsertIfNil("layer1")
		data:Set("layer1", "key", "value")
		expect(data.buffer.key).to.equal("value")
	end)

	it("should use 2 layers, newest overwriting old", function()
		local data = DataEmbedded.new(MockExtension)
		data:InsertIfNil("layer1")
		data:InsertIfNil("layer2")
		data:Set("layer1", "key", "no")
		data:Set("layer2", "key", "yes")

		expect(data.buffer.key).to.equal("yes")
	end)

	it("should remove layers, maintaining the linked list", function()
		local data = DataEmbedded.new(MockExtension)
		data:InsertIfNil("layer1")
		data:InsertIfNil("layer2")
		data:InsertIfNil("layer3")

		data:Set("layer3", "key", "3")
		data:Set("layer2", "key", "2")
		data:Set("layer1", "key", "1")

		data:RemoveLayer("layer2")
		expect(data.buffer.key).to.equal("3")

		data:RemoveLayer("layer3")
		expect(data.buffer.key).to.equal("1")

		data:Set("layer1", "key", "yes")
		expect(data.buffer.key).to.equal("yes")
	end)

	it("should compute transforms on get", function()
		local data = DataEmbedded.new(MockExtension)
		data:InsertIfNil("layer1")
		data:InsertIfNil("layer2")
		data:InsertIfNil("layer3")
		data:InsertIfNil("layer4")

		data:Set("layer3", "key", Ops.add(2))
		data:Set("layer2", "key", 1)
		expect(data.buffer.key).to.equal(3)

		data:Set("layer2", "key", Ops.add(2))
		expect(data.buffer.key).to.equal(4)

		data:Set("layer4", "key", 2)
		expect(data.buffer.key).to.equal(2)
	end)

	local function betweenLayerTest(method)
		local data = DataEmbedded.new(MockExtension)
		data:InsertIfNil("layer1")
		data:InsertIfNil("layer2")

		data:Set("layer1", "test", false)
		data:Set("layer1", "test2", true)
		data:Set("layer2", "test", "moo")
		
		local key = "layer1.5"
		method(data, key, {
			test = true;
		})

		expect(data.buffer.test).to.equal("moo")
		expect(data.layers[key].test).to.equal(true)
		expect(data.layers[key].test2).to.equal(true)
	end

	it("should set a layer right after the key's layer", function()
		betweenLayerTest(function(data, keyToSet, layerToSet)
			data:CreateLayerAfter("layer1", keyToSet, layerToSet)
		end)
	end)

	it("should set a layer right before the key's layer", function()
		betweenLayerTest(function(data, keyToSet, layerToSet)
			data:CreateLayerBefore("layer2", keyToSet, layerToSet)
		end)
	end)

	it("should throw a type error", function()
		local data = DataEmbedded.new(MockExtension, {
			number = t.number;
			string = t.string;
		})

		expect(function()
			data:SetLayer("layer1", {
				number = 1;
				string = 2;
			})
		end).to.throw()
		expect(data.buffer.number).to.equal(nil)

		expect(function()
			data:Set("layer1", "string", 1)
		end).to.throw()
		expect(data.buffer.string).to.equal(nil)

		data:SetLayer("layer1", {
			number = 1;
		})

		expect(function()
			data:Set("layer1", "number", Ops.wrap(function() return "string" end))
		end).to.throw()
	end)

	it("should generate an object representing a key's current value", function()
		local data = DataEmbedded.new(MockExtension)
		data:InsertIfNil("base")

		local object = data:GetObject("test")
		expect(object:Get()).to.equal(nil)
		expect(data:GetObject("test")).to.equal(object)

		data:Set("base", "test", 1)
		expect(object:Get()).to.equal(1)

		local called = {}
		object:For(function(value)
			table.insert(called, value)
		end)

		expect(#called).to.equal(1)
		expect(called[1]).to.equal(1)

		data:Set("base", "test", 2)
		data:onUpdate()
		expect(#called).to.equal(2)
		expect(called[2]).to.equal(2)
	end)

	it("should set a layer at the proper priority position", function()
		local data = DataEmbedded.new(MockExtension)
		data:CreateLayerAtPriority("test", 1, {key = 1})
		expect(data.buffer.key).to.equal(1)

		data:CreateLayerAtPriority("test2", 0, {key = 0})
		expect(data.buffer.key).to.equal(1)

		data:CreateLayerAtPriority("test3", 2, {key = 2})
		expect(data.buffer.key).to.equal(2)
	end)

	local function transformTableTest(wrapper)
		local data = DataEmbedded.new(MockExtension)
		data:InsertIfNil("layer1")
		data:InsertIfNil("layer2")

		local injected = {test1 = true}
		data:Set("layer1", "transform", wrapper(injected))
		data:Set("layer2", "transform", Ops.merge({test2 = true}))

		expect(injected.test1).to.equal(true)
		expect(injected.test2).to.equal(nil)
		
		local merged = data.buffer.transform
		expect(merged).to.never.equal(injected)
		expect(merged.test1).to.equal(true)
		expect(merged.test2).to.equal(true)
	end

	it("should copy transform's injected table before passing it to the next transforms", function()
		transformTableTest(Ops.merge)
	end)

	it("should copy table before passing it to transforms", function()
		transformTableTest(function(tbl) return tbl end)
	end)
end