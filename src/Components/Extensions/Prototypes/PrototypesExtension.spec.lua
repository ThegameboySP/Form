local CollectionService = game:GetService("CollectionService")

local Manager = require(script.Parent.Parent.Parent).Manager
local BaseComponent = require(script.Parent.Parent.Parent).BaseComponent
local Prototypes = require(script.Parent)
local Utils = require(script.Parent.Utils)

local TestComponent = BaseComponent:extend("TestComponent")

local new = Instance.new

local function shallowEquals(src, tbl)
	for _, t in pairs({src, tbl}) do
		for k, v in pairs(t) do
			if v ~= tbl[k] or v ~= src[k] then
				return false
			end
		end
	end
	
	return true
end

local function count(tbl)
	local c = 0
	for _ in pairs(tbl) do
		c += 1
	end

	return c
end

local function make()
	local m = Manager.new("Test")
	m:RegisterComponent(BaseComponent)
	Prototypes.use(m)

	return m
end

return function()
	describe("Utils", function()
		it("should get attribute configuration", function()
			local i = new("Folder")
			i:SetAttribute("Test_bool", true)
			i:SetAttribute("Test_string", "test")

			expect(shallowEquals(Utils.getConfigFromInstance(i, "Test"), {
				bool = true;
				string = "test";
			})).to.equal(true)
		end)

		it("should get folder configuration", function()
			local i = new("Folder")
			local ref = new("Folder")

			local c = new("Configuration")
			c.Parent = i
			local f = new("Folder")
			f.Name = "Test"
			f.Parent = c

			local o = new("ObjectValue")
			o.Value = ref
			o.Name = "Reference"
			o.Parent = f

			expect(shallowEquals(Utils.getConfigFromInstance(i, "Test"), {
				Reference = ref;
			})).to.equal(true)
		end)

		it("should generate 1 prototype from root", function()
			local root = Instance.new("BoolValue")
			CollectionService:AddTag(root, "Test")

			local prototypes = Utils.generatePrototypesFromRoot({"Test"}, root, {})
			expect(count(prototypes)).to.equal(1)
		end)

		it("should generate 3 prototypes from root", function()
			local root = Instance.new("BoolValue")
			CollectionService:AddTag(root, "Test")

			local b = new("BoolValue")
			b.Parent = root
			CollectionService:AddTag(b, "Test")
			local b2 = new("BoolValue")
			b2.Parent = root
			CollectionService:AddTag(b2, "Test")

			local prototypes = Utils.generatePrototypesFromRoot({"Test"}, root, {})
			expect(count(prototypes)).to.equal(3)
		end)
	end)

	describe("Extension", function()
		local function setupEnv()
			local folder = new("Folder")
			local test = new("Folder")
			test.Name = "Test"
			test.Parent = folder
			CollectionService:AddTag(test, "BaseComponent")

			return folder, test
		end

		it("Init: should deparent prototype and add it to tables", function()
			local man = make()
			local env, test = setupEnv()

			man.Prototypes:Init(env)
			expect(test.Parent).to.equal(nil)
			expect(man.Prototypes:GetPrototype(test)).to.be.ok()
		end)

		it("Run: should clone prototype, set its old parent, and add it to tables", function()
			local man = make()
			local env, test = setupEnv()

			man.Prototypes:Init(env)
			man.Prototypes:RunAll()
			expect(env.Test).to.be.ok()
			expect(man.Prototypes:GetCloneProfileFromPrototype(test)).to.be.ok()
		end)

		it("Init workflow: should delete a clone after all components are removed", function()
			local man = make()
			local env = setupEnv()

			man.Prototypes:Init(env)
			man.Prototypes:RunAll()

			expect(env.Test).to.be.ok()
			man.Prototypes:Stop({env.Test})
			expect(env:FindFirstChild("Test")).to.equal(nil)
		end)

		it("Init: should work with IInstance", function()
			local man = make()
			man:RegisterComponent(TestComponent)

			function TestComponent.getInterfaces(t)
				return {IInstance = t.instanceOf("Folder")}
			end

			local _, test = setupEnv()
			man.Prototypes:Init(test)
			expect(man.Prototypes:GetPrototype(test)).to.be.ok()

			function TestComponent.getInterfaces(t)
				return {IInstance = t.instanceOf("BasePart")}
			end

			local man2 = make()
			man2:RegisterComponent(TestComponent)
			local _, test2 = setupEnv()
			man2.Prototypes:Init(test2)

			TestComponent.getInterfaces = nil
			expect(man2.Prototypes:GetPrototype(test)).to.equal(nil)
		end)

		it("Init: should never mutate prototypes", function()
			local man = make()
			local _, test = setupEnv()
			man.Prototypes:Init(test)

			expect(#CollectionService:GetTags(test)).to.equal(1)
			expect(#test:GetChildren()).to.equal(0)
			expect(count(test:GetAttributes())).to.equal(0)

			man.Prototypes:RestorePrototype(man.Prototypes:GetPrototype(test))

			expect(#CollectionService:GetTags(test)).to.equal(1)
			expect(#test:GetChildren()).to.equal(0)
			expect(count(test:GetAttributes())).to.equal(0)
		end)

		it("RunAndMergeFilter: should run and merge with a filter", function()
			local man = make()
			local env, test = setupEnv()
			test.Name = "Test1"

			local test2 = Instance.new("BoolValue")
			test2.Parent = env
			test2.Name = "Test2"
			CollectionService:AddTag(test2, "BaseComponent")

			man.Prototypes:Init(env)
			man.Prototypes:RunFilter(function(prototype)
				return prototype.instance.Name == "Test1"
			end)

			expect(env:FindFirstChild("Test1")).to.be.ok()
			expect(env:FindFirstChild("Test2")).to.never.be.ok()

			man.Prototypes:RunFilter(function()
				return true
			end)

			expect(env:FindFirstChild("Test1")).to.be.ok()
			expect(env:FindFirstChild("Test2")).to.be.ok()
		end)

		it("DestroyClonesFilter: should destroy clones with a filter", function()
			local man = make()

			local env = setupEnv()
			local test2 = Instance.new("BoolValue")
			test2.Parent = env
			test2.Name = "Test2"
			CollectionService:AddTag(test2, "BaseComponent")

			man.Prototypes:Init(env)
			man.Prototypes:RunAll()
			man.Prototypes:DestroyClonesFilter(function(clone, prototype)
				return clone.Name == "Test1" and prototype ~= nil
			end)

			expect(env:FindFirstChild("Test1")).to.never.be.ok()
			expect(env:FindFirstChild("Test2")).to.be.ok()

			man.Prototypes:DestroyClonesFilter(function()
				return true
			end)

			expect(env:FindFirstChild("Test1")).to.never.be.ok()
			expect(env:FindFirstChild("Test2")).to.never.be.ok()
		end)
	end)
end