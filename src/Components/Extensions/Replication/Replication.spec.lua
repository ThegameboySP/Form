local Manager = require(script.Parent.Parent.Parent.Form.Manager)
local BaseComponent = require(script.Parent.Parent.Parent.Form.BaseComponent)
local Replication = require(script.Parent)

local function makeServer(callbacks)
	callbacks = callbacks or {}
	local server = Manager.new("server")
	server.IsServer = true
	server.IsTesting = true
	server:RegisterComponent(BaseComponent)

	callbacks.onReplicatedOnce = callbacks.onReplicatedOnce or function(comp, onReplicated)
		onReplicated(comp)
	end
	Replication.use(server, callbacks)

	return server
end

local function makeClient(overrides)
	local client = Manager.new("client")
	client.IsServer = false
	client.IsTesting = true
	client:RegisterComponent(BaseComponent)
	Replication.use(client, nil, overrides)

	return client
end

local function makeServerAndClient(callbacks)
	local server = makeServer(callbacks)
	return server, makeClient(server.Replication.remotes)
end

local function connect(server, client)
	server.Replication._fire = function(_, eventName, _, ...)
		client.Replication["_on" .. eventName](client.Replication, ...)
	end
	server.Replication._fireAll = function(_, eventName, ...)
		client.Replication["_on" .. eventName](client.Replication, ...)
	end

	return server, client
end

local function newRef()
	return Instance.new("Folder")
end

return function()
	it("should replicate existing components to connecting player", function()
		local ref = newRef()

		local firePlayerAdded
		local server = makeServer({
			subscribePlayerAdded = function(onPlayerAdded)
				firePlayerAdded = onPlayerAdded
			end;
		})
		
		server:GetOrAddComponent(ref, BaseComponent)

		local client = makeClient(server.Replication.remotes)
		connect(server, client)
		firePlayerAdded()

		expect(client:GetComponent(ref, BaseComponent)).to.be.ok()
	end)

	it("should replicate state changes to existing players", function()
		local ref = newRef()
		local server, client = connect(makeServerAndClient())

		local comp = server:GetOrAddComponent(ref, BaseComponent)

		comp.Layers:Set("base", "Test", 1)
		comp.Layers:onUpdate()
		expect(client:GetComponent(ref, BaseComponent).Layers.buffer.Test).to.equal(1)
	end)

	it("should fully test a replicated component's lifecycle to existing players", function()
		local ref = newRef()

		local fireReplicated
		local server, client = connect(makeServerAndClient({
			onReplicatedOnce = function(_, onReplicated)
				fireReplicated = onReplicated
			end;
		}))

		local comp = server:GetOrAddComponent(ref, BaseComponent)
		expect(client:GetComponent(ref, BaseComponent)).to.never.be.ok()

		fireReplicated(comp)
		expect(client:GetComponent(ref, BaseComponent)).to.be.ok()

		ref.Parent = nil
		expect(client:GetComponent(ref, BaseComponent)).to.be.ok()

		server:RemoveComponent(ref, BaseComponent)
		expect(client:GetComponent(ref, BaseComponent)).to.never.be.ok()
	end)
end