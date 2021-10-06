-- local Manager = require(script.Parent.Parent.Parent.Form.Manager)
-- local BaseComponent = require(script.Parent.Parent.Parent.Form.BaseComponent)
-- local spy = require(script.Parent.Parent.Parent.Testing.spy)
-- local Groups = require(script.Parent)

-- local function make()
-- 	local m = Manager.new("Test")
-- 	m:RegisterComponent(BaseComponent)
-- 	Groups.use(m)

-- 	return m
-- end

-- local new = Instance.new

-- return function()
-- 	describe("Extension", function()
-- 		it("should make all components have Default group by default", function()
-- 			local man = make()
-- 			local i = new("Folder")
-- 			man:GetOrAddComponent(i, "BaseComponent")

-- 			expect(man.Groups:Has(i, "Default")).to.equal(true)
-- 		end)

-- 		it("should always throw when trying to Add or Remove non-registered references", function()
-- 			local man = make()
-- 			local i = new("Folder")

-- 			expect(function()
-- 				man.Groups:Add(i, "Test")
-- 			end).to.throw()

-- 			expect(function()
-- 				man.Groups:Remove(i, "Test")
-- 			end).to.throw()
-- 		end)

-- 		it("should return an array of reference's groups", function()
-- 			local man = make()
-- 			local i = new("Folder")
-- 			man:GetOrAddComponent(i, "BaseComponent")
-- 			man.Groups:Add(i, "Test")

-- 			local a = man.Groups:Get(i)
-- 			expect(#a).to.equal(2)
-- 			expect(a[1]).to.equal("Default")
-- 			expect(a[2]).to.equal("Test")
-- 		end)
-- 	end)

-- 	describe(".Groups", function()
-- 		local TestComponent = BaseComponent:extend("TestComponent")
-- 		TestComponent.Groups = {"Test1", "Test2"}

-- 		it("should automatically assign groups on ComponentAdded if .Groups exists", function()
-- 			local man = make()
-- 			man:RegisterComponent(TestComponent)
-- 			local i = new("Folder")
-- 			man:GetOrAddComponent(i, TestComponent)

-- 			expect(man.Groups:Has(i, "Test1")).to.equal(true)
-- 			expect(man.Groups:Has(i, "Test2")).to.equal(true)
-- 		end)
-- 	end)

-- 	describe("Add", function()
-- 		it("should never fire Added when a reference is already added", function()
-- 			local man = make()
-- 			local i = new("Folder")
-- 			man:GetOrAddComponent(i, "BaseComponent")
-- 			local t = {}
-- 			man.Groups:On("Added", spy(t))

-- 			man.Groups:Add(i, "Test")
-- 			man.Groups:Add(i, "Test")

-- 			expect(t.Count).to.equal(1)
-- 		end)

-- 		it("should fire Added when adding ref to a group", function()
-- 			local man = make()
-- 			local i = new("Folder")
-- 			local t = {}
-- 			man.Groups:On("Added", spy(t))

-- 			man:GetOrAddComponent(i, "BaseComponent")
-- 			man.Groups:Add(i, "Test")

-- 			expect(t.Count).to.equal(2)
-- 			expect(t.Params[1][1]).to.equal(i)
-- 			expect(t.Params[1][2]).to.equal("Default")
-- 			expect(t.Params[2][1]).to.equal(i)
-- 			expect(t.Params[2][2]).to.equal("Test")
-- 		end)
-- 	end)

-- 	describe("Remove", function()
-- 		it("should automatically remove reference's groups once it's removed", function()
-- 			local man = make()
-- 			local i = new("Folder")
-- 			local t = {}
-- 			man.Groups:On("Removed", spy(t))

-- 			local comp = man:GetOrAddComponent(i, "BaseComponent")
-- 			man:RemoveComponent(i, "BaseComponent")

-- 			expect(t.Count).to.equal(1)
-- 			expect(man.Groups:Get(i)[1]).to.equal(nil)
-- 			expect(comp.isDestroyed).to.equal(true)
-- 		end)

-- 		it("should never fire Removed when a reference is already removed", function()
-- 			local man = make()
-- 			local i = new("Folder")
-- 			man:GetOrAddComponent(i, "BaseComponent")
-- 			local t = {}
-- 			man.Groups:On("Removed", spy(t))

-- 			man.Groups:Add(i, "Test")
-- 			man.Groups:Remove(i, "Test")
-- 			man.Groups:Remove(i, "Test")

-- 			expect(t.Count).to.equal(1)
-- 		end)
-- 	end)
-- end

return function()
end