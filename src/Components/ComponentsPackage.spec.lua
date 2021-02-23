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

			local profile = man:GetCloneProfileFromPrototype(instance)
			expect(profile:IsInGroup("Main")).to.equal(true)

			local instance2 = Instance.new("BoolValue")
			man:AddComponent(instance2, "TestComponent")

			local profile2 = man:GetCloneProfile(instance2)
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
			expect(instance.Configuration.Groups:FindFirstChild("Test2")).to.be.ok()
		end)

		-- group subscription, state subscription, etc
		it("should destruct subscription to external state on removing clone profile", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			local folder = Instance.new("Folder")
			local instance = Instance.new("BoolValue", folder)
			CollectionService:AddTag(instance, "TestComponent")

			man:Init(folder)
			man:RunAndMerge({
				Main = true;
			})
			man:AddToGroup(folder.Value, "Test")

			local tag = Instance.new("BoolValue")
			tag.Name = "ComponentsSyncronized"
			tag.Archivable = false
			tag.Value = true
			tag.Parent = folder.Value

			expect(man:IsAdded(folder.Value, "TestComponent")).to.equal(true)

			local man2 = ComponentsManager.new()
			man2:RegisterComponent(TestComponent)

			man2:Init(folder)
			man2:RunAndMerge({
				Main = true;
			})

			local profile = man2:GetCloneProfile(folder.Value)
			expect(next(profile:GetDestructFunctionsArray())).to.be.ok()

			man2:RemoveComponent(folder.Value, "TestComponent")
			expect(next(profile:GetDestructFunctionsArray())).to.equal(nil)
		end)

		it("should allow another manager to immediately syncronize group and state after initialization", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			local folder = Instance.new("Folder")
			local instance = Instance.new("BoolValue", folder)
			CollectionService:AddTag(instance, "TestComponent")

			man:Init(folder)
			man:RunAndMerge({
				Main = true;
			})
			man:AddToGroup(folder.Value, "Test")

			local tag = Instance.new("BoolValue")
			tag.Name = "ComponentsSyncronized"
			tag.Archivable = false
			tag.Value = true
			tag.Parent = folder.Value

			expect(man:IsAdded(folder.Value, "TestComponent")).to.equal(true)

			local man2 = ComponentsManager.new()
			man2:RegisterComponent(TestComponent)

			man2:Init(folder)
			man2:RunAndMerge({
				Main = true;
			})

			local state1 = man:GetState(folder.Value, "TestComponent")
			local state2 = man2:GetState(folder.Value, "TestComponent")
			expect(ComponentsUtils.shallowCompare(state1, state2)).to.equal(true)

			man:SetState(folder.Value, "TestComponent", {test = true})
			state1 = man:GetState(folder.Value, "TestComponent")
			state2 = man2:GetState(folder.Value, "TestComponent")
			
			expect(ComponentsUtils.shallowCompare(state1, state2)).to.equal(true)
			expect(man2:IsInGroup(folder.Value, "Test")).to.equal(true)

			man:RemoveFromGroup(folder.Value, "Test")
			expect(man2:IsInGroup(folder.Value, "Test")).to.equal(false)

			man:AddToGroup(folder.Value, "Test2")
			expect(man2:IsInGroup(folder.Value, "Test2")).to.equal(true)
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

		it("should throw when inputting wrong config", function()
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

	describe("Individual components level", function()
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

		it("should successfully change state value type", function()
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

			local state = ComponentsUtils.getComponentState(ComponentsUtils.getComponentStateFolder(instance2, "TestComponent"))
			expect(type(state.state1)).to.equal("string")
			expect(type(state.state2)).to.equal("string")
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