local Manager = require(script.Parent.Parent.Manager)
local BaseComponent = require(script.Parent.Parent.BaseComponent)
local spy = require(script.Parent.Parent.Parent.Testing.spy)

local function make()
	local m = Manager.new("test")
	m:RegisterComponent(BaseComponent)
	return m
end

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

local function count(dict)
	local m = 0
	for _ in pairs(dict) do
		m += 1
	end
	return m
end

local new = Instance.new

return function()
	describe("Register", function()
		it("should register a valid component", function()
			local m = Manager.new("test")
			local c = m._collection
			m:RegisterComponent(BaseComponent)
			expect(c._classesByName.BaseComponent).to.equal(BaseComponent)
			expect(c._classesByRef[BaseComponent]).to.equal(BaseComponent)
		end)

		it("should always throw when registering a component twice", function()
			local m = make()
			expect(function()
				m:RegisterComponent(BaseComponent)
			end).to.throw()
		end)

		it("should always throw when an improper component is registered", function()
			local m = make()

			expect(function()
				m:RegisterComponent(true)
			end).to.throw()

			local TestComp = BaseComponent:extend("Test")
			TestComp.ClassName = true
			expect(function()
				m:RegisterComponent(TestComp)
			end).to.throw()
		end)
	end)

	describe("GetOrAddComponent", function()
		it("should add a component and fire ComponentAdded once", function()
			local m = make()
			local t = {}
			m:On("ComponentAdded", spy(t))

			local i = new("Folder")
			local comp = m:GetOrAddComponent(i, "BaseComponent")

			expect(t.Count).to.equal(1)
			expect(t.Params[1][1]).to.equal(comp)
		end)

		it("should never add a component twice to the same reference", function()
			local m = make()
			local t = {}
			m:On("ComponentAdded", spy(t))

			local i = new("Folder")
			m:GetOrAddComponent(i, "BaseComponent")
			m:GetOrAddComponent(i, "BaseComponent")

			expect(t.Count).to.equal(1)
		end)

		it("should return component when it already exists", function()
			local m = make()

			local i = new("Folder")
			local comp, id1 = m:GetOrAddComponent(i, "BaseComponent")
			local ret2, id2 = m:GetOrAddComponent(i, "BaseComponent")

			expect(ret2).to.equal(comp)
			expect(id1).to.never.equal(id2)
		end)
	end)
	
	describe("BulkAddComponent", function()
		local function add(refs)
			local m = make()
			local t = {}
			m:On("ComponentAdded", spy(t))

			local classes = {"BaseComponent", "BaseComponent"}
			local keywords = {{config = {test1 = true}}, {config = {test2 = true}}}
			local comps, compIds = m:BulkAddComponent(refs, classes, keywords)

			for i=1, t.Count do
				expect(t.Params[i][1]).to.equal(comps[i])
				expect(shallowEquals(t.Params[i][2], keywords[i].config)).to.equal(true)
			end

			return comps, compIds, t
		end

		it("should add components and fire ComponentAdded in order", function()
			local comps, compIds, t = add({new("Folder"), new("Folder")})
			expect(#comps).to.equal(2)
			expect(t.Count).to.equal(2)

			expect(count(compIds)).to.equal(2)
			for _, ids in pairs(compIds) do
				expect(#ids).to.equal(1)
				expect(ids[1]).to.equal("base")
			end
		end)

		it("should never add a component twice to same reference", function()
			local i = new("Folder")
			local comps, compIds, t = add({i, i})

			expect(#comps).to.equal(1)
			expect(t.Count).to.equal(1)

			expect(count(compIds)).to.equal(1)
			local ids = compIds[comps[1]]
			expect(ids[1]).to.equal("base")
			expect(ids[2]).to.be.ok()
		end)

		it("should add a new layer to a pre-existing component, not firing ComponentAdded", function()
			local i = new("Folder")
			local m = make()
			local comp, id = m:GetOrAddComponent(i, BaseComponent)
			expect(id).to.equal("base")

			local t = {}
			m:On("ComponentAdded", spy(t))

			local comps, compIds = m:BulkAddComponent({i}, {BaseComponent}, {})
			expect(t.Count).to.equal(0)
			expect(#comps).to.equal(1)
			expect(count(compIds)).to.equal(1)
			expect(compIds[comp][1]).to.never.equal(BASE)
		end)
	end)

	describe("RemoveComponent", function()
		it("should remove a component and fire ComponentRemoved once", function()
			local m = make()
			local t = {}
			m:On("ComponentRemoved", spy(t))

			local i = new("Folder")
			local comp = m:GetOrAddComponent(i, "BaseComponent")
			m:RemoveComponent(i, "BaseComponent")

			expect(t.Count).to.equal(1)
			expect(t.Params[1][1]).to.equal(comp)
		end)

		it("should automatically remove a component that was destroyed", function()
			local m = make()
			local t = {}
			m:On("ComponentRemoved", spy(t))

			local i = new("Folder")
			local comp = m:GetOrAddComponent(i, "BaseComponent")
			comp:Destroy()

			expect(t.Count).to.equal(1)
			expect(t.Params[1][1]).to.equal(comp)
		end)

		it("should remove a reference and fire RefRemoved once", function()
			local m = make()
			local t = {}
			m:On("RefRemoved", spy(t))
			local t2 = {}
			m:On("ComponentRemoved", spy(t2))

			local i = new("Folder")
			m:GetOrAddComponent(i, "BaseComponent")
			m:RemoveRef(i)
			
			expect(t.Count).to.equal(1)
			expect(t2.Count).to.equal(1)
		end)
	end)
end