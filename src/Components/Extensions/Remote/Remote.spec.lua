local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Manager = require(script.Parent.Parent.Parent.Form.Manager)
local BaseComponent = require(script.Parent.Parent.Parent.Form.BaseComponent)
local Remote = require(script.Parent)

local function serverAndClient(class)
	local overrides = {
		event = Instance.new("RemoteEvent");
		callback = Instance.new("RemoteFunction");
	}

	local server = Manager.new("server")
	server.IsServer = true
	server.IsTesting = true
	server:RegisterComponent(class or BaseComponent)
	Remote.use(server, overrides)

	local client = Manager.new("client")
	client.IsServer = false
	client.IsTesting = true
	client:RegisterComponent(class or BaseComponent)
	Remote.use(client, overrides)

	return server, client, overrides
end

local function newRef()
	local ref = Instance.new("Folder")
	ref.Name = "FormRemoteTestRef (should not see this)"
	ref.Parent = ReplicatedStorage
	task.delay(0, function()
		ref.Parent = nil
	end)

	return ref
end

return function()
	it("should replicate event", function()
		local serverArgs = {}
		local clientArgs = {}
		local ref = newRef()

		local server, client = serverAndClient()
		local serverComp = server:GetOrAddComponent(ref, BaseComponent)
		serverComp:On("ClientTest", function(_, arg)
			table.insert(serverArgs, arg)
		end)

		local clientComp = client:GetOrAddComponent(ref, BaseComponent)
		clientComp:On("ServerTest", function(arg)
			table.insert(clientArgs, arg)
		end)

		clientComp.Remote:FireServer("Test", "test1")
		serverComp.Remote:FireAllClients("Test", "test2")
		wait(0.1)

		expect(#serverArgs).to.equal(1)
		expect(serverArgs[1]).to.equal("test1")
		expect(#clientArgs).to.equal(1)
		expect(clientArgs[1]).to.equal("test2")
	end)

	it("should replicate functions", function()
		local serverArgs = {}
		local ref = newRef()

		local server, client = serverAndClient()
		local serverComp = server:GetOrAddComponent(ref, BaseComponent)
		server.Remote:OnInvoke(serverComp, "Callback", function(_, arg)
			table.insert(serverArgs, arg)
			return true
		end)
		local clientComp = client:GetOrAddComponent(ref, BaseComponent)

		local ret = clientComp.Remote:Invoke("Callback", "test")
		expect(ret).to.equal(true)
		expect(#serverArgs).to.equal(1)
		expect(serverArgs[1]).to.equal("test")
	end)

	it("should predict", function()
		local ref = newRef()
		local server, client = serverAndClient()

		local compServer = server:GetOrAddComponent(ref, BaseComponent)
		server.Remote:OnInvoke(compServer, "Test", function(_, arg)
			if arg == "arg" then
				return true
			end
		end)

		local compClient = client:GetOrAddComponent(ref, BaseComponent)

		local co = coroutine.running()
		client.Remote:Predict(compClient, "Test", "arg", {test = true}, function(ok)
			task.spawn(co, ok)
		end)
		expect(compClient.data.test).to.equal(true)

		local ok = coroutine.yield()
		expect(ok).to.equal(true)
		expect(compClient.data.test).to.equal(nil)
	end)
end