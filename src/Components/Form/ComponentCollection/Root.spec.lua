local Manager = require(script.Parent.Parent.Manager)
local BaseComponent = require(script.Parent.Parent.BaseComponent)
local spy = require(script.Parent.Parent.Parent.Testing.spy)

local function run(class, ref)
	local resolvedClass = class
	local man = Manager.new("test")
	man:RegisterComponent(class)
	man.IsTesting = true

	local comp = man:GetOrAddComponent(ref or Instance.new("Folder"), resolvedClass)
	return comp
end

return function()
	it("should invoke :Init and :Start in order, once", function()
		local ExpectationComponent = BaseComponent:extend("Test")

		local t1 = {}
		ExpectationComponent.Init = spy(t1)
		local t2 = {}
		ExpectationComponent.Start = spy(t2)

		local comp = run(ExpectationComponent)
		expect(t1.Count).to.equal(1)
		expect(t1.Params[1][1]).to.equal(comp)
		expect(t2.Count).to.equal(1)
		expect(t2.Params[1][1]).to.equal(comp)
	end)

	it("CheckRef: should error on bad reference", function()
		local ExpectationComponent = BaseComponent:extend("Test", {
			CheckRef = function(i)
				return i:IsA("Folder")
			end;
		})

		expect(function()
			run(ExpectationComponent, {})
		end).to.throw()

		expect(function()
			run(ExpectationComponent, Instance.new("Folder"))
		end).to.never.throw()
	end)
end