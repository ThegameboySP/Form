local Data = require(script.Parent.Data)
local t = require(script.Parent.Parent.Parent.Modules.t)
local Ops = require(script.Parent.Ops)
local BaseComponent = require(script.Parent)
local TestComponent = BaseComponent:extend("TestComponent")

local MockExtension = {
	SetDirty = function() end;
}

return function()
	local comp = TestComponent:run()

	it("should use 1 layer", function()
		local data = Data.new(MockExtension, comp)
		data:InsertIfNil("layer1")
		data:Set("layer1", "key", "value")
		expect(data.buffer.key).to.equal("value")
	end)

	it("should use 2 layers, newest overwriting old", function()
		local data = Data.new(MockExtension, comp)
		data:InsertIfNil("layer1")
		data:InsertIfNil("layer2")
		data:Set("layer1", "key", "no")
		data:Set("layer2", "key", "yes")

		expect(data.buffer.key).to.equal("yes")
	end)

	it("should remove layers, maintaining the linked list", function()
		local data = Data.new(MockExtension, comp)
		data:InsertIfNil("layer1")
		data:InsertIfNil("layer2")
		data:InsertIfNil("layer3")

		data:Set("layer3", "key", "3")
		data:Set("layer2", "key", "2")
		data:Set("layer1", "key", "1")

		data:Remove("layer2")
		expect(data.buffer.key).to.equal("3")

		data:Remove("layer3")
		expect(data.buffer.key).to.equal("1")

		data:Set("layer1", "key", "yes")
		expect(data.buffer.key).to.equal("yes")
	end)

	it("should compute transforms on get", function()
		local data = Data.new(MockExtension, comp)
		data:InsertIfNil("layer1")
		data:InsertIfNil("layer2")
		data:InsertIfNil("layer3")
		data:InsertIfNil("layer4")

		data:Set("layer3", "key", Ops.add(2))
		data:Set("layer2", "key", 1)
		expect(data:Get("key")).to.equal(3)

		data:Set("layer2", "key", Ops.add(2))
		expect(data:Get("key")).to.equal(4)

		data:Set("layer4", "key", 2)
		expect(data:Get("key")).to.equal(2)
	end)

	it("should set a layer right after the key's layer", function()
		local data = Data.new(MockExtension, comp)
		data:InsertIfNil("layer1")
		data:InsertIfNil("layer2")

		data:Set("layer1", "test", false)
		data:Set("layer1", "test2", true)
		data:Set("layer2", "test", "moo")
		local key = data:CreateLayerAt("layer1", "layer1.5", {
			test = true;
		})

		expect(rawget(data.layersArray[2], "test")).to.equal(true)
		expect(data.top.test).to.equal("moo")
		expect(data.layers[key].test).to.equal(true)
		expect(data.layers[key].test2).to.equal(true)
	end)

	it("should throw a type error", function()
		local data = Data.new(MockExtension, comp, {
			number = t.number;
			string = t.string;
		})

		expect(function()
			data:SetLayer("layer1", {
				number = 1;
				string = 2;
			})
		end).to.throw()
		expect(data:Get("number")).to.equal(nil)

		expect(function()
			data:Set("string", 1)
		end).to.throw()
		expect(data:Get("string")).to.equal(nil)

		data:SetLayer("layer1", {
			number = 1;
		})
	end)

	it("should return an array of values for the key, ignoring default layer", function()
		local data = Data.new(MockExtension, comp)
		data:SetLayer(data.Default, {
			test = 1;
		})
		data:SetLayer("layer1", {
			test = Ops.add(1);
		})
		data:SetLayer("layer2", {
			test = Ops.add(2);
		})
		data:SetLayer("layer3", {
			test = 3;
		})
		data:SetLayer("layer4", {
			test = Ops.add(1);
		})
		data:SetLayer("layer5", {
			test = 5;
		})
		
		local values = data:GetValues("test")
		expect(#values).to.equal(3)
		expect(values[1]).to.equal(3)
		expect(values[2]).to.equal(4)
		expect(values[3]).to.equal(5)
	end)

	it("should always respect the final layer", function()
		local data = Data.new(MockExtension, comp)
		data:SetLayer(data.Final, {})
		data:SetLayer("layer2", {})

		expect(data.layersArray[1]).to.equal(data.layers[data.Final])
		expect(data.top).to.equal(data.layers[data.Final])
		expect(data.layersArray[2]).to.equal(data.layers.layer2)
	end)
end