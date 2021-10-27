local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Manager = require(script.Parent.Parent.Parent.Form.Manager)
local BaseComponent = require(script.Parent.Parent.Parent.Form.BaseComponent)
local Replication = require(script.Parent)

local function makeOverrides()
	return {
		ComponentAdded = Instance.new("RemoteEvent");
		ComponentRemoved = Instance.new("RemoteEvent");
		StateChanged = Instance.new("RemoteEvent");
	}
end

local function makeServer(callbacks)
	local overrides = makeOverrides()

	local server = Manager.new("server")
	server.IsServer = true
	server.IsTesting = true
	server:RegisterComponent(BaseComponent)
	Replication.use(server, callbacks, overrides)

	return server, overrides
end

local function makeClient(overrides)
	local client = Manager.new("client")
	client.IsServer = false
	client.IsTesting = true
	client:RegisterComponent(BaseComponent)
	Replication.use(client, nil, overrides)

	return client
end

local function serverAndClient()
	local server, overrides = makeServer()
	return server, makeClient(overrides)
end

local function replicate(ref, timeout)
	ref.Parent = ReplicatedStorage
	task.delay(timeout or 0, function()
		ref.Parent = nil
	end)

	return ref
end

local function newRef()
	local ref = Instance.new("Folder")
	ref.Name = "FormReplicationTestRef (should not see this)"

	return ref
end

return function()
	it("should replicate existing components to connecting player", function()
		local ref = replicate(newRef(), 1)

		local firePlayerAdded
		local server = makeServer({
			FireInitialClient = function(self, _, comp, data)
				self.remotes.ComponentAdded:FireAllClients(
					self.man.Serializers:Serialize(comp), data
				)
			end;

			SubscribePlayerAdded = function(onPlayerAdded)
				firePlayerAdded = onPlayerAdded
			end;
		})
		
		server:GetOrAddComponent(ref, BaseComponent)
		wait(0.1)

		-- Make new remote events so that we clear the queue.
		local newOverrides = makeOverrides()
		server.Replication.remotes = newOverrides

		local client = makeClient(newOverrides)
		firePlayerAdded()
		wait(0.1)

		expect(client:GetComponent(ref, BaseComponent)).to.be.ok()
	end)

	it("should replicate state changes to existing players", function()
		local ref = replicate(newRef())
		local server, client = serverAndClient()

		local comp = server:GetOrAddComponent(ref, BaseComponent)

		wait(0.1)
		comp.Data:Set("base", "Test", 1)

		wait(0.1)
		expect(client:GetComponent(ref, BaseComponent).Data:Get("Test")).to.equal(1)
	end)

	it("should fully test a replicated component's lifecycle to existing players", function()
		local ref = newRef()
		local server, client = serverAndClient()

		server:GetOrAddComponent(ref, BaseComponent)
		wait(0.1)
		expect(client:GetComponent(ref, BaseComponent)).to.never.be.ok()

		replicate(ref)
		wait(0.1)
		expect(client:GetComponent(ref, BaseComponent)).to.be.ok()

		ref.Parent = nil
		wait(0.1)
		expect(client:GetComponent(ref, BaseComponent)).to.be.ok()

		server:RemoveComponent(ref, BaseComponent)
		wait(0.1)
		expect(client:GetComponent(ref, BaseComponent)).to.never.be.ok()
	end)
end