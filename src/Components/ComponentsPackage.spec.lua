-- local CollectionService = game:GetService("CollectionService")

-- local ComponentsManager = require(script.Parent.ComponentsManager)
-- local Components = require(script.Parent.Components)
-- local ComponentsUtils = require(script.Parent.ComponentsUtils)
-- local BaseComponent = require(script.Parent).BaseComponent

-- local TestComponent = setmetatable({}, {__index = BaseComponent})
-- TestComponent.ComponentName = "TestComponent"
-- TestComponent.__index = TestComponent

-- function TestComponent.new(...)
-- 	return setmetatable(BaseComponent.new(...), TestComponent)
-- end

-- return function()
-- 	describe("Components manager", function()
-- 		it("should always throw when indexing invalid key of NetworkMode", function()
-- 			expect(function()
-- 				local _ = ComponentsManager.NetworkMode.DGsfsfsdfsdfsdfsddblah
-- 			end).to.throw()
-- 		end)
		
-- 		it("should sucessfully register component", function()
-- 			local man = ComponentsManager.new()

-- 			expect(function()
-- 				man:RegisterComponent(TestComponent)
-- 			end).to.never.throw()
-- 		end)

-- 		it("should throw on registering component twice", function()
-- 			local man = ComponentsManager.new()

-- 			expect(function()
-- 				man:RegisterComponent(TestComponent)
-- 				man:RegisterComponent(TestComponent)
-- 			end).to.throw()
-- 		end)

-- 		it("should generate 1 prototype from root", function()
-- 			local root = Instance.new("BoolValue")
-- 			CollectionService:AddTag(root, "Test")

-- 			local prototypes = ComponentsManager.generatePrototypesFromRoot({"Test"}, root, ComponentsManager.ComponentMode.RESPAWN, {})
-- 			local cnt = 0
-- 			for _ in next, prototypes do
-- 				cnt += 1
-- 			end

-- 			expect(cnt).to.equal(1)
-- 		end)

-- 		it("should generate 3 prototypes from root", function()
-- 			local root = Instance.new("BoolValue")
-- 			CollectionService:AddTag(root, "Test")

-- 			CollectionService:AddTag( Instance.new("BoolValue", root), "Test" )
-- 			CollectionService:AddTag( Instance.new("BoolValue", root), "Test" )

-- 			local prototypes = ComponentsManager.generatePrototypesFromRoot({"Test"}, root, ComponentsManager.ComponentMode.RESPAWN, {})
-- 			local cnt = 0
-- 			for _ in next, prototypes do
-- 				cnt += 1
-- 			end

-- 			expect(cnt).to.equal(3)
-- 		end)

-- 		it("should make all components have Default group by default", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local instance = Instance.new("BoolValue")
-- 			CollectionService:AddTag(instance, "TestComponent")

-- 			man:Init(instance)
-- 			man:RunAndMergeAll()

-- 			local profile = man:GetCloneProfileFromPrototype(instance)
-- 			expect(profile:IsInGroup("Default")).to.equal(true)

-- 			local instance2 = Instance.new("BoolValue")
-- 			man:AddComponent(instance2, "TestComponent")

-- 			local profile2 = man:GetCloneProfile(instance2)
-- 			expect(profile2:IsInGroup("Default")).to.equal(true)
-- 		end)

-- 		it("should handle _getClonesFromGroups correctly", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			for _, group in next, {"one", "two", "three"} do
-- 				local instance = Instance.new("BoolValue")
-- 				man:AddComponent(instance, "TestComponent")
-- 				man:AddToGroup(instance, group)
-- 			end

-- 			expect(#man:_getClonesFromGroups({one = true})).to.equal(1)
-- 			expect(#man:_getClonesFromGroups({one = true; two = true})).to.equal(2)
-- 			expect(#man:_getClonesFromGroups({one = true; two = true, three = true})).to.equal(3)
-- 			expect(#man:_getClonesFromGroups({Default = true})).to.equal(3)
-- 			expect(#man:_getClonesFromGroups({Default = true; one = true; two = true, three = true})).to.equal(3)
-- 		end)

-- 		it("should handle repeated AddToGroup and RemoveFromGroup calls without throwing", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local instance = Instance.new("BoolValue")
-- 			man:AddComponent(instance, "TestComponent")

-- 			expect(function()
-- 				man:AddToGroup(instance, "Test")
-- 				man:AddToGroup(instance, "Test")
-- 			end).never.to.throw()

-- 			expect(function()
-- 				man:RemoveFromGroup(instance, "Test")
-- 				man:RemoveFromGroup(instance, "Test")
-- 			end).never.to.throw()
-- 		end)

-- 		it("should always remove clone when removing all groups", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local folder = Instance.new("Folder")
-- 			local instance = Instance.new("BoolValue", folder)
-- 			man:AddComponent(instance, "TestComponent")
-- 			man:AddToGroup(instance, "Test")

-- 			man:RemoveFromGroup(instance, "Default")

-- 			expect(instance.Parent).to.be.ok()

-- 			man:RemoveFromGroup(instance, "Test")

-- 			expect(instance.Parent).to.equal(nil)
-- 		end)

-- 		it("should keep internal and external groups in sync", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local instance = Instance.new("BoolValue", folder)
-- 			man:AddComponent(instance, "TestComponent")
-- 			expect(ComponentsUtils.getGroups(instance).Default).to.equal(true)

-- 			man:AddToGroup(instance, "Test")
-- 			expect(ComponentsUtils.getGroups(instance).Test).to.equal(true)

-- 			man:RemoveFromGroup(instance, "Default")
-- 			expect(ComponentsUtils.getGroups(instance).Default).to.equal(nil)

-- 			man:AddToGroup(instance, "Test2")
-- 			man:RemoveFromGroup(instance, "Test")

-- 			expect(ComponentsUtils.getGroups(instance).Test).to.equal(nil)
-- 			expect(ComponentsUtils.getGroups(instance).Test2).to.be.ok()
-- 		end)

-- 		it("should destruct subscription to group and generic state on removing clone profile", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local folder = Instance.new("Folder")
-- 			local instance = Instance.new("BoolValue", folder)
-- 			CollectionService:AddTag(instance, "TestComponent")

-- 			man:Init(folder)
-- 			man:RunAndMergeInGroups({
-- 				Default = true;
-- 			})
-- 			man:AddToGroup(folder.Value, "Test")

-- 			folder.Value:SetAttribute("CompositeClone", true)

-- 			expect(man:IsAdded(folder.Value, "TestComponent")).to.equal(true)

-- 			local man2 = ComponentsManager.new()
-- 			man2:RegisterComponent(TestComponent)

-- 			man2:Init(folder)
-- 			man2:RunAndMergeInGroups({
-- 				Default = true;
-- 			})

-- 			local profile = man2:GetCloneProfile(folder.Value)
-- 			expect(next(profile:GetDestructFunctionsArray())).to.be.ok()

-- 			man2:RemoveComponent(folder.Value, "TestComponent")
-- 			expect(next(profile:GetDestructFunctionsArray())).to.equal(nil)
-- 		end)

-- 		it("should allow another manager to immediately syncronize group and state after initialization", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local folder = Instance.new("Folder")
-- 			local instance = Instance.new("BoolValue", folder)
-- 			CollectionService:AddTag(instance, "TestComponent")

-- 			man:Init(folder)
-- 			man:RunAndMergeInGroups({
-- 				Default = true;
-- 			})
-- 			man:AddToGroup(folder.Value, "Test")

-- 			expect(man:IsAdded(folder.Value, "TestComponent")).to.equal(true)

-- 			local man2 = ComponentsManager.new()
-- 			man2:RegisterComponent(TestComponent)

-- 			man2:Init(folder)
-- 			man2:RunAndMergeInGroups({
-- 				Default = true;
-- 			})

-- 			local state1 = man:GetState(folder.Value, "TestComponent")
-- 			local state2 = man2:GetState(folder.Value, "TestComponent")
-- 			expect(ComponentsUtils.shallowCompare(state1, state2)).to.equal(true)

-- 			man:SetState(folder.Value, "TestComponent", {test = true})
-- 			state1 = man:GetState(folder.Value, "TestComponent")
-- 			state2 = man2:GetState(folder.Value, "TestComponent")
			
-- 			expect(ComponentsUtils.shallowCompare(state1, state2)).to.equal(true)
-- 			expect(man2:IsInGroup(folder.Value, "Test")).to.equal(true)

-- 			man:RemoveFromGroup(folder.Value, "Test")
-- 			expect(man2:IsInGroup(folder.Value, "Test")).to.equal(false)

-- 			man:AddToGroup(folder.Value, "Test2")
-- 			expect(man2:IsInGroup(folder.Value, "Test2")).to.equal(true)
-- 		end)

-- 		it("Init: should clone a prototype and remove the old one", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local folder = Instance.new("Folder")
-- 			local instance = Instance.new("BoolValue", folder)
-- 			CollectionService:AddTag(instance, "TestComponent")

-- 			man:Init(folder)
-- 			man:RunAndMergeInGroups({
-- 				Default = true;
-- 			})

-- 			expect(instance.Parent).to.equal(nil)
-- 			expect(folder:FindFirstChild("Value")).to.be.ok()
-- 		end)

-- 		it("Init workflow: should delete a clone after all components are removed", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local folder = Instance.new("Folder")
-- 			local instance = Instance.new("BoolValue")
-- 			instance.Name = "Test"
-- 			instance.Parent = folder

-- 			CollectionService:AddTag(instance, "TestComponent")
-- 			man:Init(instance)
-- 			man:RunAndMergeAll()

-- 			expect(folder:FindFirstChild("Test")).to.be.ok()
-- 			man:Stop({folder.Test})
-- 			expect(folder:FindFirstChild("Test")).to.equal(nil)
-- 		end)

-- 		it("Init: should never initialize an instance that doesn't fit in IInstance", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			function TestComponent.getInterfaces(t)
-- 				return {
-- 					IInstance = t.instanceOf("BasePart");
-- 				}
-- 			end

-- 			local instance = Instance.new("Folder")
-- 			CollectionService:AddTag(instance, "TestComponent")
-- 			man:Init(instance)

-- 			TestComponent.getInterfaces = nil
-- 			expect(man:GetCloneProfileFromPrototype(instance)).to.equal(nil)
-- 		end)

-- 		it("Init: should never mutate prototypes", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local instance = Instance.new("BoolValue")
-- 			CollectionService:AddTag(instance, "TestComponent")
-- 			man:Init(instance)

-- 			expect(#CollectionService:GetTags(instance)).to.equal(1)
-- 			expect(#instance:GetChildren()).to.equal(0)
-- 		end)

-- 		it("RunAndMergeSynced: should sync and run another manager's instance", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local instance = Instance.new("BoolValue")
-- 			man:AddComponent(instance, "TestComponent", nil, {componentMode = "Respawn"})

-- 			local man2 = ComponentsManager.new()
-- 			man2:RegisterComponent(TestComponent)

-- 			man2:Init(instance)
-- 			local newComponents = man2:RunAndMergeSynced()

-- 			expect(next(newComponents)).to.be.ok()
-- 		end)

-- 		it("RunAndMergeFilter: should run and merge with a filter", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local folder = Instance.new("Folder")
-- 			local instance = Instance.new("BoolValue")
-- 			instance.Name = "Test1"
-- 			instance.Parent = folder
-- 			local instance2 = Instance.new("BoolValue")
-- 			instance2.Parent = folder
-- 			instance2.Name = "Test2"

-- 			CollectionService:AddTag(instance, "TestComponent")
-- 			CollectionService:AddTag(instance2, "TestComponent")

-- 			man:Init(folder)
-- 			man:RunAndMergeFilter(function(prototype)
-- 				return prototype.instance.Name == "Test1"
-- 			end)

-- 			expect(folder:FindFirstChild("Test1")).to.be.ok()
-- 			expect(folder:FindFirstChild("Test2")).to.never.be.ok()

-- 			man:RunAndMergeFilter(function()
-- 				return true
-- 			end)

-- 			expect(folder:FindFirstChild("Test1")).to.be.ok()
-- 			expect(folder:FindFirstChild("Test2")).to.be.ok()
-- 		end)

-- 		it("DestroyClonesFilter: should destroy clones with a filter", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local folder = Instance.new("Folder")
-- 			local instance = Instance.new("BoolValue")
-- 			instance.Name = "Test1"
-- 			instance.Parent = folder
-- 			local instance2 = Instance.new("BoolValue")
-- 			instance2.Parent = folder
-- 			instance2.Name = "Test2"

-- 			man:AddComponent(instance, "TestComponent")
-- 			man:AddComponent(instance2, "TestComponent")

-- 			man:DestroyClonesFilter(function(clone, prototype)
-- 				return clone.Name == "Test1" and prototype ~= nil
-- 			end)

-- 			expect(folder:FindFirstChild("Test1")).to.never.be.ok()
-- 			expect(folder:FindFirstChild("Test2")).to.be.ok()

-- 			man:DestroyClonesFilter(function()
-- 				return true
-- 			end)

-- 			expect(folder:FindFirstChild("Test1")).to.never.be.ok()
-- 			expect(folder:FindFirstChild("Test2")).to.never.be.ok()
-- 		end)

-- 		it("RestorePrototypesInGroups: should restore prototypes in groups", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local folder = Instance.new("Folder")
-- 			local instance = Instance.new("BoolValue")
-- 			instance.Name = "Test1"
-- 			instance:SetAttribute("CompositeGroup_Testy1", true)
-- 			instance.Parent = folder
-- 			local instance2 = Instance.new("BoolValue")
-- 			instance2.Parent = folder
-- 			instance2:SetAttribute("CompositeGroup_Testy2", true)
-- 			instance2.Name = "Test2"

-- 			CollectionService:AddTag(instance, "TestComponent")
-- 			CollectionService:AddTag(instance2, "TestComponent")

-- 			man:Init(folder)
-- 			man:RestorePrototypesInGroups({Testy1 = true})

-- 			expect(folder:FindFirstChild("Test1")).to.equal(instance)
-- 			expect(folder:FindFirstChild("Test2")).to.never.equal(instance2)

-- 			man:RestorePrototypesInGroups({Testy2 = true})

-- 			expect(folder:FindFirstChild("Test1")).to.equal(instance)
-- 			expect(folder:FindFirstChild("Test2")).to.equal(instance2)
-- 		end)

-- 		it("AddComponent: should add a clone to internal tables", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local folder = Instance.new("Folder")
-- 			local instance = Instance.new("BoolValue", folder)
-- 			local obj, config = man:AddComponent(instance, "TestComponent")

-- 			expect(getmetatable(obj)).to.be.equal(TestComponent)
-- 			expect(type(config)).to.equal("table")
-- 			expect(man:GetCloneProfile(instance)).to.be.ok()
-- 			expect(man:GetComponent(instance, "TestComponent")).to.be.ok()
-- 			expect(man:IsInGroup(instance, "Default")).to.be.ok()
-- 			expect(instance.Parent).to.be.ok()
-- 		end)

-- 		it("AddComponent: should destroy instance and respawn with ComponentMode.Respawn", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local instance = Instance.new("BoolValue")
-- 			instance.Parent = Instance.new("Folder")
-- 			man:AddComponent(instance, "TestComponent", nil, {componentMode = "Respawn"})
-- 			local prototype = man:GetCloneProfile(instance).prototype.instance

-- 			man:DestroyClonesInGroups({Default = true})
-- 			expect(instance.Parent).to.equal(nil)
-- 			man:RunAndMergeInGroups({Default = true})

-- 			local profile = man:GetCloneProfileFromPrototype(prototype)
-- 			expect(profile).to.be.ok()
-- 			expect(profile.clone.Parent).to.be.ok()
-- 		end)

-- 		it("AddComponent: should destroy instance and not respawn with ComponentMode.NoRespawn", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local instance = Instance.new("BoolValue")
-- 			man:AddComponent(instance, "TestComponent", nil, {componentMode = "NoRespawn"})
-- 			local prototype = man:GetCloneProfile(instance).prototype.instance

-- 			man:DestroyClonesInGroups({Default = true})
-- 			man:RunAndMergeInGroups({Default = true})

-- 			expect(man:GetCloneProfileFromPrototype(prototype)).to.equal(nil)
-- 		end)

-- 		it("AddComponent: shouldn't destroy instance or respawn with ComponentMode.Overlay", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local instance = Instance.new("BoolValue")
-- 			instance.Parent = Instance.new("Folder")
			
-- 			man:AddComponent(instance, "TestComponent", nil, {componentMode = "Overlay"})
-- 			local prototype = man:GetCloneProfile(instance).prototype.instance

-- 			man:DestroyClonesInGroups({Default = true})
-- 			expect(instance.Parent).to.be.ok()
-- 			man:RunAndMergeInGroups({Default = true})

-- 			expect(instance.Parent).to.be.ok()
-- 			expect(#instance.Parent:GetChildren()).to.equal(1)
-- 			expect(man:GetCloneProfileFromPrototype(prototype)).to.equal(nil)
-- 		end)

-- 		it("DestroyClonesInGroups: should completely remove a clone from internal tables", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local folder = Instance.new("Folder")
-- 			local instance = Instance.new("BoolValue", folder)
-- 			local obj, config = man:AddComponent(instance, "TestComponent")

-- 			man:DestroyClonesInGroups({Default = true})

-- 			expect(getmetatable(obj)).to.be.equal(TestComponent)
-- 			expect(type(config)).to.equal("table")
-- 			expect(man:GetCloneProfile(instance)).to.equal(nil)
-- 			expect(man:GetComponent(instance, "TestComponent")).to.equal(nil)
-- 			expect(man:IsInGroup(instance, "Default")).to.equal(false)
-- 			expect(instance.Parent).to.equal(nil)
-- 		end)

-- 		it("DestroyClonesInGroups: should leave prototypes in tact", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local instance = Instance.new("BoolValue")
-- 			CollectionService:AddTag(instance, "TestComponent")
-- 			local prototype = man:Init(instance)[1]

-- 			expect(man:GetPrototype(prototype.instance)).to.be.ok()

-- 			man:DestroyClonesInGroups({Default = true})

-- 			expect(prototype.instance.Parent).to.equal(nil)
-- 			expect(man:GetPrototype(prototype.instance)).to.be.ok()
-- 		end)

-- 		it("should remove all Composite influence from instance prototype and restore it", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local instance = Instance.new("BoolValue")
-- 			instance.Parent = Instance.new("Folder")

-- 			CollectionService:AddTag(instance, "TestComponent")

-- 			man:Init(instance)
-- 			man:RestorePrototypes()

-- 			expect(#CollectionService:GetTags(instance)).to.equal(1)
-- 			expect(#instance:GetChildren()).to.equal(0)
-- 			expect(next(instance:GetAttributes())).to.equal(nil)
-- 			expect(instance.Parent).to.be.ok()

-- 			for _, group in next, man:_getGroups() do
-- 				expect(#group:GetAdded()).to.equal(0)
-- 			end
-- 		end)

-- 		it("RemoveClone: should remove all Composite influence from ComponentMode.Overlay instance", function()
-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			local instance = Instance.new("BoolValue")
-- 			instance.Parent = Instance.new("Folder")

-- 			man:AddComponent(instance, "TestComponent", nil, {componentMode = "Overlay"})
-- 			man:RemoveClone(instance)

-- 			expect(#CollectionService:GetTags(instance)).to.equal(0)
-- 			expect(#instance:GetChildren()).to.equal(0)
-- 			expect(next(instance:GetAttributes())).to.equal(nil)
-- 		end)

-- 		it("PrePass: should replace ModuleScripts with ObjectValues and put back once restored", function()
-- 			local instance = Instance.new("BoolValue")
-- 			local config = Instance.new("Configuration")
-- 			local fdr = Instance.new("Folder")
-- 			fdr.Name = "TestComponent"
-- 			fdr.Parent = config

-- 			local module = Instance.new("ModuleScript")
-- 			module.Parent = fdr

-- 			config.Parent = instance

-- 			local man = ComponentsManager.new()
-- 			man:RegisterComponent(TestComponent)

-- 			man:AddComponent(instance, "TestComponent", nil, {onlyServer = true})

-- 			expect(module.Parent).to.never.equal(fdr)

-- 			man:StopAll()
-- 			man:RestorePrototypes()

-- 			expect(module.Parent).to.equal(fdr)
-- 			expect(#fdr:GetChildren()).to.equal(1)
-- 		end)
-- 	end)

-- 	describe("Components type", function()
-- 		local comp = setmetatable({}, {__index = TestComponent})
-- 		function comp.getInterfaces(t)
-- 			return {
-- 				IConfiguration = t.strictInterface({
-- 					test = t.boolean;
-- 				})
-- 			}
-- 		end

-- 		local components = Components.new({}, comp, "Component", error)
-- 		local instance = Instance.new("BoolValue")

-- 		it("should return nil when inputting wrong config", function()
-- 			local obj = components:AddComponent(Instance.new("BoolValue"), {
-- 				test = nil;
-- 			})
-- 			expect(obj).to.equal(nil)
-- 		end)

-- 		it("should add new component", function()
-- 			local didCallNew = false
-- 			function comp.new(...)
-- 				didCallNew = true
-- 				return TestComponent.new(...)
-- 			end

-- 			components:AddComponent(instance, {
-- 				test = true;
-- 			})

-- 			expect(didCallNew).to.equal(true)
-- 		end)

-- 		it("should know it's added", function()
-- 			expect(components:IsAdded(instance)).to.equal(true)
-- 		end)

-- 		it("should remove new component", function()
-- 			local didCallDestroy = false
-- 			function comp:Destroy()
-- 				didCallDestroy = true
-- 				TestComponent.Destroy(self)
-- 			end

-- 			components:RemoveComponent(instance)

-- 			expect(didCallDestroy).to.equal(true)
-- 		end)
-- 	end)

-- 	describe("Components util", function()
-- 		it("should get 2 groups from instance", function()
-- 			local folder = Instance.new("Folder")
-- 			folder:SetAttribute("CompositeGroup_Test", true)
-- 			folder:SetAttribute("CompositeGroup_Test2", true)

-- 			local groups = ComponentsUtils.getGroups(folder)
-- 			expect(groups.Test).to.be.ok()
-- 			expect(groups.Test2).to.be.ok()
-- 		end)

-- 		it("should support groups trees", function()
-- 			local folder = Instance.new("Folder")
-- 			local folder2 = Instance.new("Folder")
-- 			folder2.Parent = folder

-- 			folder:SetAttribute("CompositeGroup_Test", true)

-- 			local groups = ComponentsUtils.getGroups(folder2)
-- 			expect(groups.Test).to.be.ok()
-- 		end)

-- 		it("should subscribe to changes in group", function()
-- 			local folder = Instance.new("Folder")
-- 			ComponentsUtils.updateInstanceGroups(folder, {Default = true}, {})
			
-- 			local groups = {}
-- 			local destruct = ComponentsUtils.subscribeGroupsAnd(folder, function(groupName, isInGroup)
-- 				groups[groupName] = isInGroup
-- 			end)

-- 			expect(groups.Default).to.equal(true)

-- 			ComponentsUtils.updateInstanceGroups(folder, {Default = true, Test = true}, {Default = true})

-- 			expect(groups.Default).to.equal(true)
-- 			expect(groups.Test).to.equal(true)

-- 			ComponentsUtils.updateInstanceGroups(folder, {}, {Default = true, Test = true})

-- 			expect(groups.Default).to.equal(false)
-- 			expect(groups.Test).to.equal(false)

-- 			destruct()
-- 		end)

-- 		it("should update instance config", function()
-- 			local instance = Instance.new("Folder")
-- 			ComponentsUtils.updateInstanceConfig(instance, "Test", {
-- 				str = "str";
-- 				bool = true;
-- 				Vector = Vector3.new();
-- 				CFrame = CFrame.new(1, 1, 1);
-- 				Instance = Instance.new("Folder");
-- 			})

-- 			local config = ComponentsUtils.getConfigFromInstance(instance, "Test")
-- 			expect(config.str).to.equal("str")
-- 			expect(config.bool).to.equal(true)
-- 			expect(config.Vector).to.equal(Vector3.new())
-- 			expect(config.CFrame).to.equal(CFrame.new(1, 1, 1))
-- 			expect(config.Instance.ClassName).to.equal("Folder")
-- 		end)
-- 	end)
-- end

return function() end