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
			local prototypes = ComponentsManager.generatePrototypesFromRoot({"Test"}, root)
			local cnt = 0
			for _ in next, prototypes do
				cnt += 1
			end

			expect(cnt).to.equal(1)
		end)

		it("should generate 3 prototypes from root", function()
			CollectionService:AddTag( Instance.new("BoolValue", root), "Test" )
			CollectionService:AddTag( Instance.new("BoolValue", root), "Test" )

			local prototypes = ComponentsManager.generatePrototypesFromRoot({"Test"}, root)
			local cnt = 0
			for _ in next, prototypes do
				cnt += 1
			end

			expect(cnt).to.equal(3)
		end)

		it("Init: should clone a prototype and remove the old one", function()
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

		it("Init: should delete a clone after all components are removed", function()
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

		it("Init: should never initialize an instance that doesn't fit in IInstance", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			function TestComponent.getInterfaces(t)
				return {
					IInstance = t.instanceOf("BasePart");
				}
			end

			local instance = Instance.new("Folder")
			CollectionService:AddTag(instance, "TestComponent")
			man:Init(instance)

			TestComponent.getInterfaces = nil
			expect(man:GetCloneProfileFromPrototype(instance)).to.equal(nil)
		end)

		it("Init: should never mutate prototypes", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			local instance = Instance.new("BoolValue")
			CollectionService:AddTag(instance, "TestComponent")
			man:Init(instance)

			expect(#CollectionService:GetTags(instance)).to.equal(1)
			expect(#instance:GetChildren()).to.equal(0)
		end)

		it("should make all components have Main group by default", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			local instance = Instance.new("BoolValue")
			CollectionService:AddTag(instance, "TestComponent")

			man:Init(instance)
			man:RunAndMergeAll()

			local profile = man:GetCloneProfileFromPrototype(instance)
			expect(profile:IsInGroup("Main")).to.equal(true)

			local instance2 = Instance.new("BoolValue")
			man:AddComponent(instance2, "TestComponent")

			local profile2 = man:GetCloneProfile(instance2)
			expect(profile2:IsInGroup("Main")).to.equal(true)
		end)

		it("should handle _getPrototypesFromGroups correctly", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			for _, group in next, {"one", "two", "three"} do
				man:AddToGroup( man:AddComponent(Instance.new("BoolValue"), "TestComponent").clone, group)
			end

			expect(#man:_getPrototypesFromGroups({one = true})).to.equal(1)
			expect(#man:_getPrototypesFromGroups({one = true; two = true})).to.equal(2)
			expect(#man:_getPrototypesFromGroups({one = true; two = true, three = true})).to.equal(3)
			expect(#man:_getPrototypesFromGroups({Main = true})).to.equal(3)
			expect(#man:_getPrototypesFromGroups({Main = true; one = true; two = true, three = true})).to.equal(3)
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

		it("should destruct subscription to group and generic state on removing clone profile", function()
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
			tag.Name = "CompositeClone"
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

		it("AddComponent: should add a clone to internal tables", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			local folder = Instance.new("Folder")
			local instance = Instance.new("BoolValue", folder)
			local profile = man:AddComponent(instance, "TestComponent")

			expect(man:GetCloneProfileFromPrototype(profile.prototype.instance)).to.be.ok()
			expect(man:GetCloneProfile(instance)).to.be.ok()
			expect(man:GetComponent(instance, "TestComponent")).to.be.ok()
			expect(man:IsInGroup(instance, "Main")).to.be.ok()
			expect(instance.Parent).to.be.ok()
		end)

		it("AddComponent: should respawn", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			local instance = Instance.new("BoolValue")
			man:AddComponent(instance, "TestComponent", true)
			local prototype = man:GetCloneProfile(instance).prototype.instance

			man:DestroyClonesInGroups({Main = true})
			man:RunAndMerge({Main = true})

			expect(man:GetCloneProfileFromPrototype(prototype)).to.be.ok()
		end)

		it("AddComponent: shouldn't respawn", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			local instance = Instance.new("BoolValue")
			man:AddComponent(instance, "TestComponent")
			local prototype = man:GetCloneProfile(instance).prototype.instance

			man:DestroyClonesInGroups({Main = true})
			man:RunAndMerge({Main = true})

			expect(man:GetCloneProfileFromPrototype(prototype)).to.equal(nil)
		end)

		it("DestroyClonesInGroups: should completely remove a clone from internal tables", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			local folder = Instance.new("Folder")
			local instance = Instance.new("BoolValue", folder)
			local profile = man:AddComponent(instance, "TestComponent")

			man:DestroyClonesInGroups({Main = true})

			expect(man:GetCloneProfileFromPrototype(profile.prototype.instance)).to.equal(nil)
			expect(man:GetCloneProfile(instance)).to.equal(nil)
			expect(man:GetComponent(instance, "TestComponent")).to.equal(nil)
			expect(man:IsInGroup(instance, "Main")).to.equal(false)
			expect(instance.Parent).to.equal(nil)
		end)

		it("DestroyClonesInGroups: should leave prototypes in tact", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			local instance = Instance.new("BoolValue")
			CollectionService:AddTag(instance, "TestComponent")
			local prototype = man:Init(instance)[1]

			expect(man:GetPrototype(prototype.instance)).to.be.ok()

			man:DestroyClonesInGroups({Main = true})

			expect(prototype.instance.Parent).to.equal(nil)
			expect(man:GetPrototype(prototype.instance)).to.be.ok()
		end)

		it("Stop: should remove all Composite influence from instance and restore it", function()
			local man = ComponentsManager.new()
			man:RegisterComponent(TestComponent)

			local folder = Instance.new("Folder")
			local instance = Instance.new("BoolValue", folder)

			CollectionService:AddTag(instance, "TestComponent")

			man:Init(instance)
			man:Stop()

			expect(#CollectionService:GetTags(instance)).to.equal(1)
			expect(#folder:GetChildren()).to.equal(1)
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

		it("should return nil when inputting wrong config", function()
			local config = components:AddComponent(Instance.new("BoolValue"), {
				test = nil;
			})
			expect(config).to.equal(nil)
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
	describe("Components util", function()
		-- it("should properly subscribe component state", function()
		-- 	local instance2 = Instance.new("BoolValue")
		-- 	local man = ComponentsManager.new()
		-- 	man:RegisterComponent(TestComponent)
		-- 	man:AddComponent(instance2, "TestComponent", {
		-- 		test = true;
		-- 	})

		-- 	local value
		-- 	man:Subscribe(instance2, "TestComponent", "Test", function(newValue)
		-- 		value = newValue
		-- 	end)

		-- 	man:SetState(instance2, "TestComponent", {Test = true})

		-- 	expect(value).to.equal(true)
		-- end)

		it("should get 2 groups from instance", function()
			local folder = Instance.new("Folder")
			folder:SetAttribute("CompositeGroup_Test", true)
			folder:SetAttribute("CompositeGroup_Test2", true)

			local groups = ComponentsUtils.getGroups(folder)
			expect(groups.Test).to.be.ok()
			expect(groups.Test2).to.be.ok()
		end)

		it("should support tree groups", function()
			local folder = Instance.new("Folder")
			local folder2 = Instance.new("Folder")
			folder2.Parent = folder

			folder:SetAttribute("CompositeGroup_Test", true)

			local groups = ComponentsUtils.getGroups(folder2)
			expect(groups.Test).to.be.ok()
		end)
	end)
end