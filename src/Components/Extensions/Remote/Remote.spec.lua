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
	
end