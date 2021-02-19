local CollectionService = game:GetService("CollectionService")

local ComponentsManager = require(script.Parent.ComponentsManager)
local Components = require(script.Parent.Components)
local ComponentsUtils = require(script.Parent.ComponentsUtils)
local BaseComponent = require(script.Parent).BaseComponent

local TestComponent = setmetatable({}, {__index = BaseComponent})
TestComponent.ComponentName = "TestComponent"
TestComponent.__index = TestComponent

function TestComponent.new(...)
	return setmetatable(BaseComponent.new(...), TestComponent)
end

-- TODO: Test that component state and instance value objects are syncronized.

return function()
	describe("Components manager", function()
		it("should always throw when indexing invalid key of NetworkMode", function()
			expect(function()
				local _ = ComponentsManager.NetworkMode.DGsfsfsdfsdfsdfsddblah
			end).to.throw()
		end)
		
		it("should sucessfully register component", function()
			local man = ComponentsManager.new()

			expect(function()
				man:RegisterComponent(TestComponent)
			end).to.never.throw()
		end)

		it("should throw on registering component twice", function()
			local man = ComponentsManager.new()

			expect(function()
				man:RegisterComponent(TestComponent)
				man:RegisterComponent(TestComponent)
			end).to.throw()
		end)

		local root = Instance.new("BoolValue")
		CollectionService:AddTag(root, "Test")

		it("should generate 1 prototype from root", function()
			local prototypes = ComponentsManager.generatePrototypesFromRoot(root, {"Test"})
			local cnt = 0
			for _ in next, prototypes do
				cnt += 1
			end

			expect(cnt).to.equal(1)
		end)

		it("should generate 3 prototypes from root", function()
			CollectionService:AddTag( Instance.new("BoolValue", root), "Test" )
			CollectionService:AddTag( Instance.new("BoolValue", root), "Test" )

			local prototypes = ComponentsManager.generatePrototypesFromRoot(root, {"Test"})
			local cnt = 0
			for _ in next, prototypes do
				cnt += 1
			end

			expect(cnt).to.equal(3)
		end)

		it("should clone a prototype and remove the old one", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			local folder = Instance.new("Folder")
			local instance = Instance.new("BoolValue", folder)
			CollectionService:AddTag(instance, "TestComponent")

			man:Init(folder)
			man:RunAndMerge({
				Main = true;
			})

			expect(instance.Parent).to.equal(nil)
			expect(folder:FindFirstChild("Value")).to.be.ok()
		end)

		it("should delete a clone after all components are removed", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			local folder = Instance.new("Folder")
			local instance = Instance.new("BoolValue", folder)

			man:AddComponent(instance, "TestComponent", {
				test = true;
			})
			expect(instance.Parent).to.never.equal(nil)
			man:RemoveComponent(instance, "TestComponent")
			expect(instance.Parent).to.equal(nil)

			folder:Destroy()
		end)

		it("should make all components have Main group by default", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			local instance = Instance.new("BoolValue")
			CollectionService:AddTag(instance, "TestComponent")

			man:Init(instance)

			local profile = man:getCloneProfileFromPrototype(instance)
			expect(profile:IsInGroup("Main")).to.equal(true)

			local instance2 = Instance.new("BoolValue")
			man:AddComponent(instance2, "TestComponent")

			local profile2 = man:getCloneProfile(instance2)
			expect(profile2:IsInGroup("Main")).to.equal(true)
		end)

		it("should handle GetCloneProfilesFromGroups correctly", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			for _, group in next, {"one", "two", "three"} do
				man:AddToGroup( man:AddComponent(Instance.new("BoolValue"), "TestComponent").clone, group)
			end

			expect(#man:GetCloneProfilesFromGroups({one = true})).to.equal(1)
			expect(#man:GetCloneProfilesFromGroups({one = true; two = true})).to.equal(2)
			expect(#man:GetCloneProfilesFromGroups({one = true; two = true, three = true})).to.equal(3)
			expect(#man:GetCloneProfilesFromGroups({Main = true})).to.equal(3)
			expect(#man:GetCloneProfilesFromGroups({Main = true; one = true; two = true, three = true})).to.equal(3)
		end)

		it("should handle repeated AddToGroup and RemoveFromGroup calls without throwing", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			local instance = Instance.new("BoolValue")
			man:AddComponent(instance, "TestComponent")

			expect(function()
				man:AddToGroup(instance, "Test")
				man:AddToGroup(instance, "Test")
			end).never.to.throw()

			expect(function()
				man:RemoveFromGroup(instance, "Test")
				man:RemoveFromGroup(instance, "Test")
			end).never.to.throw()
		end)

		it("should always remove clone when removing all groups", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			local folder = Instance.new("Folder")
			local instance = Instance.new("BoolValue", folder)
			man:AddComponent(instance, "TestComponent")
			man:AddToGroup(instance, "Test")

			man:RemoveFromGroup(instance, "Main")

			expect(instance.Parent).to.be.ok()

			man:RemoveFromGroup(instance, "Test")

			expect(instance.Parent).to.equal(nil)
		end)

		it("should keep internal and external groups in sync", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			local instance = Instance.new("BoolValue", folder)
			man:AddComponent(instance, "TestComponent")
			
			expect(instance.Configuration.Groups.Main.Value).to.equal(true)

			man:AddToGroup(instance, "Test")

			expect(instance.Configuration.Groups.Test.Value).to.equal(true)

			man:RemoveFromGroup(instance, "Main")

			expect(instance.Configuration.Groups:FindFirstChild("Main")).to.equal(nil)

			man:AddToGroup(instance, "Test2")
			man:RemoveFromGroup(instance, "Test")

			expect(instance.Configuration.Groups:FindFirstChild("Test")).to.equal(nil)
		end)
	end)

	describe("Components type", function()
		local comp = setmetatable({}, {__index = TestComponent})
		function comp.getInterfaces(t)
			return {
				IConfiguration = t.strictInterface({
					test = t.boolean;
				})
			}
		end

		local components = Components.new({}, comp, "Component", error)
		local instance = Instance.new("BoolValue")

		it("should throw when inputting wrong props", function()
			expect(function()
				components:AddComponent(Instance.new("BoolValue"), {
					test = nil;
				})
			end).to.throw()
		end)

		it("should add new component", function()
			local didCallNew = false
			function comp.new(...)
				didCallNew = true
				return TestComponent.new(...)
			end

			components:AddComponent(instance, {
				test = true;
			})

			expect(didCallNew).to.equal(true)
		end)

		it("should know it's added", function()
			expect(components:IsAdded(instance)).to.equal(true)
		end)

		it("should remove new component", function()
			local didCallDestroy = false
			function comp:Destroy()
				didCallDestroy = true
				TestComponent.Destroy(self)
			end

			components:RemoveComponent(instance)

			expect(didCallDestroy).to.equal(true)
		end)
	end)

	describe("Components", function()
		local oldNew = TestComponent.new
		function TestComponent.new(...)
			return (oldNew(...)), {
				state1 = 2;
				state2 = 1;
			}
		end

		it("should syncronize external and internal state", function()
			local instance2 = Instance.new("BoolValue")
			local man = ComponentsManager.new()

			local v1, v2
			local s1, s2
			function TestComponent:Main()
				local stateFdr = self.instance.ComponentsPublic.TestComponent
				v1, v2 = stateFdr.state1, stateFdr.state2
				s1, s2 = self.state.state1, self.state.state2
			end

			man:RegisterComponent(TestComponent)
			man:AddComponent(instance2, "TestComponent", {
				test = true;
			})

			expect(v1.Value).to.be.ok()
			expect(v1.Value).to.equal(s1)
			expect(v2.Value).to.be.ok()
			expect(v2.Value).to.equal(s2)
		end)

		it("should syncronize external and internal state after changing it", function()
			local instance2 = Instance.new("BoolValue")
			local man = ComponentsManager.new()

			local v1, v2
			local s1, s2
			function TestComponent:Main()
				self:setState({
					state1 = 23242;
					state2 = 353453;
				})

				local stateFdr = self.instance.ComponentsPublic.TestComponent
				v1, v2 = stateFdr.state1, stateFdr.state2
				s1, s2 = self.state.state1, self.state.state2
			end

			man:RegisterComponent(TestComponent)
			man:AddComponent(instance2, "TestComponent", {
				test = true;
			})

			expect(v1.Value).to.be.ok()
			expect(v1.Value).to.equal(s1)
			expect(v2.Value).to.be.ok()
			expect(v2.Value).to.equal(s2)
		end)

		it("should never throw when changing state value type", function()
			local instance2 = Instance.new("BoolValue")
			local man = ComponentsManager.new()

			man:RegisterComponent(TestComponent)
			man:AddComponent(instance2, "TestComponent", {
				test = true;
			})

			man:SetState(instance2, "TestComponent", {
				state1 = "str1";
				state2 = "str2";
			})
		end)

		it("should syncronize external and internal state after changing state value type", function()
			local instance2 = Instance.new("BoolValue")
			local man = ComponentsManager.new()

			local v1, v2
			local s1, s2
			function TestComponent:Main()
				self:setState({
					state1 = "str1";
					state2 = "str2";
				})

				local stateFdr = self.instance.ComponentsPublic.TestComponent
				v1, v2 = stateFdr.state1, stateFdr.state2
				s1, s2 = self.state.state1, self.state.state2
			end

			man:RegisterComponent(TestComponent)
			man:AddComponent(instance2, "TestComponent", {
				test = true;
			})

			expect(v1.Value).to.be.ok()
			expect(v1.Value).to.equal(s1)
			expect(v2.Value).to.be.ok()
			expect(v2.Value).to.equal(s2)
		end)
	end)
	-- describe("Components util", function()
		
	-- end)
end