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

local function setup(keywords)
	local m = make()
	local ref = new("Folder")
	local comp = m:GetOrAddComponent(ref, BaseComponent, keywords)
	return m, ref, comp
end

return function()
	describe("Profiles", function()
		it("should create a profile on new reference", function()
			local m, ref, comp = setup()

			local profile = m:GetProfile(ref)
			expect(type(profile)).to.equal("table")
			expect(profile.ref).to.equal(ref)
			expect(profile.componentsOrder[1]).to.equal(comp)
			expect(profile.mode).to.equal("Default")
		end)

		it("should use layers of components to determine mode", function()
			local m, ref = setup()
			local profile = m:GetProfile(ref)
			expect(profile.mode).to.equal("Default")

			m:GetOrAddComponent(ref, TestComponent, {mode = "Destroy"})
			expect(profile.mode).to.equal("Destroy")
			
			m:RemoveComponent(ref, TestComponent)
			expect(profile.mode).to.equal("Default")
		end)

		it("should use the last component's mode when all components are removed", function()
			local m, ref = setup()
			m:GetOrAddComponent(ref, TestComponent, {mode = "Destroy"})
			m:RemoveComponent(ref, BaseComponent)

			local mode
			m:On("RefRemoving", function(_, profile)
				mode = profile.mode
			end)
			m:RemoveComponent(ref, TestComponent)

			expect(mode).to.equal("Destroy")
		end)
	end)

	describe("Mode", function()
		local function makeMode(keywords)
			local parent = new("Folder")
			local m, ref = setup(keywords)
			ref.Parent = parent

			return m, ref, parent
		end

		it("Overlay: should keep the instance when all components are removed", function()
			local m, ref, parent = makeMode({mode = "Overlay"})
			m:RemoveComponent(ref, BaseComponent)
			expect(ref.Parent).to.equal(parent)
		end)

		it("Destroy: should destroy the instance when all components are removed", function()
			local m, ref = makeMode({mode = "Destroy"})
			m:RemoveComponent(ref, BaseComponent)
			expect(ref.Parent).to.equal(nil)
		end)

		it("Default: should be the default mode and be identical to Overlay", function()
			local m, ref, parent = makeMode()
			m:RemoveComponent(ref, BaseComponent)
			expect(ref.Parent).to.equal(parent)
		end)
	end)

	describe("Signals", function()
		local function makeSignal(name)
			local m = make()
			local t = {}
			m:On(name, spy(t))

			local ref = new("Folder")
			local comp = m:GetOrAddComponent(ref, BaseComponent)

			return t, m:GetProfile(ref), comp
		end

		it("RefAdded", function()
			local t, profile = makeSignal("RefAdded")
			expect(t.Count).to.equal(1)
			expect(t.Params[1][1]).to.equal(profile.ref)
			expect(t.Params[1][2]).to.equal(profile)
		end)

		it("RefRemoving", function()
			local t, profile, comp = makeSignal("RefRemoving")
			comp:Destroy()

			expect(t.Count).to.equal(1)
			expect(t.Params[1][1]).to.equal(profile.ref)
			expect(t.Params[1][2]).to.equal(profile)
		end)

		it("RefRemoved", function()
			local t, profile, comp = makeSignal("RefRemoved")
			comp:Destroy()

			expect(t.Count).to.equal(1)
			expect(t.Params[1][1]).to.equal(profile.ref)
			expect(t.Params[1][2]).to.equal(profile)
		end)

		it("ComponentAdded", function()
			local t, _, comp = makeSignal("ComponentAdded")
			expect(t.Count).to.equal(1)
			expect(t.Params[1][1]).to.equal(comp)
			expect(type(t.Params[1][2])).to.equal("table")
		end)

		it("ComponentRemoved", function()
			local t, _, comp = makeSignal("ComponentRemoved")
			comp:Destroy()

			expect(t.Count).to.equal(1)
			expect(t.Params[1][1]).to.equal(comp)
		end)
	end)
end