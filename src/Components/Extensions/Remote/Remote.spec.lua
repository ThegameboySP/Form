local RunService = game:GetService("RunService")

local Manager = require(script.Parent.Parent.Parent.Form.Manager)
local BaseComponent = require(script.Parent.Parent.Parent.Form.BaseComponent)
local Remote = require(script.Parent)

local function run(ref)
	local m = Manager.new("test")
	m.IsTesting = true
	m:RegisterComponent(BaseComponent)
	Remote.use(m)

	local c = m:GetOrAddComponent(ref, BaseComponent):Run()
	return c, m
end

return function()
	it("should register remote events", function()
		local i = Instance.new("Folder")
		local c = run(i)
		c.Remote:RegisterEvents({"Test"})
		expect(i:FindFirstChildWhichIsA("RemoteEvent", true)).to.be.ok()
	end)

	it("should connect to server remote event once it's visible", function()
		local i = Instance.new("Folder")
		local s, m1 = run(i)
		m1.IsServer = true
		local c, m2 = run(i)
		m2.IsServer = false

		local values = {}
		c.Remote:Connect("Test", function(_, value)
			table.insert(values, value)
		end)
		s.Remote:RegisterEvents({"Test"})
		s.Remote:FireAllClients("Test", "test")

		RunService.Heartbeat:Wait()
		expect(#values).to.equal(1)
		expect(values[1]).to.equal("test")
	end)
end