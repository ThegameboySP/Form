local BaseComponent = require(script.Parent.Parent.BaseComponent)
local Manager = require(script.Parent)
local spy = require(script.Parent.Parent.Parent.Testing.spy)

local TestComponent = BaseComponent:extend("Test")

local new = Instance.new

local function make()
	local m = Manager.new("Test")
	m:RegisterComponent(BaseComponent)
	m:RegisterComponent(TestComponent)
	return m
end

return function()
	describe("Registration", function()
		it("should add a class to .Classes", function()
			local m = Manager.new("Test")
			m:RegisterComponent(BaseComponent)
			expect(m.Classes.BaseComponent).to.equal(BaseComponent)
		end)
	end)

	describe("Signals", function()
		local function makeSignal(name)
			local m = make()
			local t = {}
			m:On(name, spy(t))

			local ref = new("Folder")
			local comp = m:GetOrAddComponent(ref, BaseComponent)

			return t, comp
		end

		it("RefAdded", function()
			local t = makeSignal("RefAdded")
			expect(t.Count).to.equal(1)
		end)

		it("RefRemoving", function()
			local t, comp = makeSignal("RefRemoving")
			comp:Destroy()
			expect(t.Count).to.equal(1)
		end)

		it("RefRemoved", function()
			local t, comp = makeSignal("RefRemoved")
			comp:Destroy()
			expect(t.Count).to.equal(1)
		end)

		it("ComponentAdded", function()
			local t, comp = makeSignal("ComponentAdded")
			expect(t.Count).to.equal(1)
			expect(t.Params[1][1]).to.equal(comp)
			expect(type(t.Params[1][2])).to.equal("table")
		end)

		it("ComponentRemoved", function()
			local t, comp = makeSignal("ComponentRemoved")
			comp:Destroy()

			expect(t.Count).to.equal(1)
			expect(t.Params[1][1]).to.equal(comp)
		end)
	end)
end