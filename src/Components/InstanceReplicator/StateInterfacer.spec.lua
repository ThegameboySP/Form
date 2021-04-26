local StateInterfacer = require(script.Parent.StateInterfacer)

return function()
	it("should properly set value base and attribute state", function()
		local instance = Instance.new("BoolValue")
		local folder = StateInterfacer.getOrMakeStateFolder(instance, "Test")
		StateInterfacer.mergeStateValueObjects(folder, {
			Ref = instance;
			CFrame = CFrame.new();
			Ray = Ray.new(Vector3.new(), Vector3.new());
			Bool = true;
			Number = 1;
		})

		expect(folder:FindFirstChild("Ref").Value).to.equal(instance)
		expect(folder:FindFirstChild("CFrame").Value).to.equal(CFrame.new())
		expect(folder:FindFirstChild("Ray").Value).to.equal(Ray.new(Vector3.new(), Vector3.new()))
		expect(folder:GetAttribute("Bool")).to.equal(true)
		expect(folder:GetAttribute("Number")).to.equal(1)
	end)

	it("should successfully change value base type", function()
		local instance = Instance.new("BoolValue")
		local folder = StateInterfacer.getOrMakeStateFolder(instance, "Test")
		StateInterfacer.mergeStateValueObjects(folder, {
			Ref = instance;
		})

		expect(folder:FindFirstChild("Ref").Value).to.equal(instance)

		StateInterfacer.mergeStateValueObjects(folder, {
			Ref = CFrame.new();
		})

		expect(folder:FindFirstChild("Ref").Value).to.equal(CFrame.new())
	end)

	it("should allow for setting state values to nil", function()
		local instance = Instance.new("BoolValue")
		local folder = StateInterfacer.getOrMakeStateFolder(instance, "Test")
		StateInterfacer.mergeStateValueObjects(folder, {
			Ref = instance;
			Attribute = true;
			Lingering = true;
		})

		expect(folder:FindFirstChild("Ref").Value).to.equal(instance)
		expect(folder:GetAttribute("Attribute")).to.equal(true)
		expect(folder:GetAttribute("Lingering")).to.equal(true)

		StateInterfacer.mergeStateValueObjects(folder, {
			Ref = StateInterfacer.NULL;
			Attribute = StateInterfacer.NULL;
		})

		expect(folder:FindFirstChild("Ref")).to.equal(nil)
		expect(folder:GetAttribute("Attribute")).to.equal(nil)
		expect(folder:GetAttribute("Lingering")).to.equal(true)
	end)

	it("should allow nested state", function()
		local instance = Instance.new("BoolValue")
		local folder = StateInterfacer.getOrMakeStateFolder(instance, "Test")
		StateInterfacer.mergeStateValueObjects(folder, {
			Nest1 = {
				Nest2 = {
					Test2 = true;
				};
				Test1 = true;
			};
			Test = true;
		})

		expect(folder:GetAttribute("Test")).to.equal(true)
		expect(folder:FindFirstChild("Nest1")).to.be.ok()
		expect(folder.Nest1:GetAttribute("Test1")).to.equal(true)
		expect(folder.Nest1:FindFirstChild("Nest2")).to.be.ok()
		expect(folder.Nest1.Nest2:GetAttribute("Test2")).to.be.ok()
	end)

	it("should get component state properly", function()
		local instance = Instance.new("BoolValue")
		local folder = StateInterfacer.getOrMakeStateFolder(instance, "Test")
		StateInterfacer.mergeStateValueObjects(folder, {
			Nest1 = {
				Nest2 = {
					Test2 = true;
				};
				Test1 = true;
			};
			Test = true;
		})

		local state = StateInterfacer.getComponentState(folder)
		expect(state.Nest1.Nest2.Test2).to.equal(true)
		expect(state.Nest1.Test1).to.equal(true)
		expect(state.Test).to.equal(true)
	end)

	do
		local function getValueAtPath(tbl, path)
			local current = tbl
			for name in path:gmatch("%.?(%w+)") do
				current = tbl[name]
			end

			return current
		end
		
		-- it("should subscribe component state properly", function()
		-- 	local delta = {
		-- 		Nest1 = {
		-- 			Test1 = true;
		-- 		};
		-- 		Outside = true;
		-- 	}

		-- 	local instance = Instance.new("BoolValue")
		-- 	local folder = StateInterfacer.getOrMakeStateFolder(instance, "Test")
		-- 	local destruct = StateInterfacer.subscribeComponentState(folder, function(path, value)
		-- 		expect()
		-- 	end)

		-- 	StateInterfacer.mergeStateValueObjects(folder, delta)


		-- end)
	end
end