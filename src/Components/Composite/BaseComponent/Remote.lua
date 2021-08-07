local CollectionService = game:GetService("CollectionService")

local bp = require(script.Parent.Parent.Parent.Modules.bp)
local Maid = require(script.Parent.Parent.Parent.Modules.Maid)
local UserUtils = require(script.Parent.Parent.User.UserUtils)

local Remote = {}
Remote.ClassName = "Remote"
Remote.__index = Remote

local ON_SERVER_ERROR = "Can only be called on the server!"
local NO_REMOTE_ERROR = "No remote event under %s by name %s!"

function Remote.new(base)
	return setmetatable({
		_base = base;
		_maid = Maid.new();
	}, Remote)
end


function Remote:Destroy()
	self._maid:DoCleaning()
end


function Remote:RegisterEvents(...)
	assert(typeof(self._base.ref) == "Instance")
	assert(self._base.isServer, ON_SERVER_ERROR)

	local folder = getOrMakeRemoteEventFolder(self._base.ref, self._base.BaseName)
	for k, v in next, {...} do
		local remote = Instance.new("RemoteEvent")

		if type(v) == "function" then
			remote.Name = tostring(k)
			self:BindEvent(remote.Name, v)
		elseif type(v) == "string" then
			remote.Name = v
		end

		remote.Parent = folder
	end

	folder:SetAttribute("Loaded", true)
end


function Remote:_getRemoteEventSchema(func)
	return bp.new(self._base.ref, {
		[bp.childNamed("RemoteEvents")] = {
			[bp.childNamed(self._base.BaseName)] = {
				[bp.attribute("Loaded", true)] = func or function(context)
					local remoteFdr = context.source.ref
					return remoteFdr
				end
			}
		}
	})
end

function Remote:FireAllClients(eventName, ...)
	assert(typeof(self._base.ref) == "Instance")

	local remote = getOrMakeRemoteEventFolder(self._base.ref, self._base.BaseName):FindFirstChild(eventName)
	if remote == nil then
		error(NO_REMOTE_ERROR:format(self._base.ref:GetFullName(), eventName))
	end

	if not self._base.isTesting then
		local args = {...}
		UserUtils.callOnReplicated(self._base.ref, self._maid, function()
			remote:FireAllClients(table.unpack(args, 1, #args))
		end)
	else
		remote:FireAllClients(...)
	end
end


function Remote:FireClient(eventName, client, ...)
	assert(typeof(self._base.ref) == "Instance")

	local remote = getOrMakeRemoteEventFolder(self._base.ref, self._base.BaseName):FindFirstChild(eventName)
	if remote == nil then
		error(NO_REMOTE_ERROR:format(self._base.ref:GetFullName(), eventName))
	end

	if not self._base.isTesting then
		local args = {...}
		UserUtils.callOnReplicated(self._base.ref, self._base.maid, function()
			remote:FireClient(client, table.unpack(args, 1, #args))
		end)
	else
		remote:FireClient(client, ...)
	end
end


function Remote:FireServer(eventName, ...)
	assert(typeof(self._base.ref) == "Instance")

	local maid, id = self._maid:Add(Maid.new())
	local schema = maid:Add(self:_getRemoteEventSchema(function()
		return false, {
			[bp.childNamed(eventName)] = function(context)
				return context.instance
			end
		}
	end))

	local args = {...}
	schema:OnMatched(function(remote)
		self._maid:Remove(id)
		remote:FireServer(table.unpack(args, 1, #args))
	end)
end


function Remote:BindEvent(eventName, handler)
	assert(typeof(self._base.ref) == "Instance")
	return self._maid:AddAuto(self:_connectEvent(eventName, handler))
end


function Remote:_connectEvent(eventName, handler)
	local maid = Maid.new()
	-- Wait a frame, as remote event connections can fire immediately if in queue.
	maid:Add(self._base.Binding:SpawnNextFrame(function()
		if self._base.isServer and not self._base.isTesting then
			maid:Add(
				(getOrMakeRemoteEventFolder(self._base.ref, self._base.BaseName)
				:FindFirstChild(eventName) or error("No event named " .. eventName .. "!"))
				.OnServerEvent:Connect(handler)
			)
		else
			local bind = self._base.isServer and "OnServerEvent" or "OnClientEvent"
			local schema = maid:Add(self:_getRemoteEventSchema(function()
				return false, {
					[bp.childNamed(eventName)] = function(context)
						return context.instance
					end
				}
			end))

			schema:OnMatched(function(remote)
				maid:DoCleaning()
				maid:Add(remote[bind]:Connect(handler))
			end)
		end
	end))

	return maid
end

function getOrMakeRemoteEventFolder(instance, baseCompName)
	local remoteEvents = instance:FindFirstChild("RemoteEvents")
	if remoteEvents == nil then
		remoteEvents = Instance.new("Folder")
		remoteEvents.Name = "RemoteEvents"
		remoteEvents.Parent = instance
		
		CollectionService:AddTag(remoteEvents, "CompositeCrap")
	end

	local folder = remoteEvents:FindFirstChild(baseCompName)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = baseCompName
		folder.Parent = remoteEvents
	end

	return folder
end

function getRemoteEventFolderOrError(instance, baseCompName)
	local remotes = instance:FindFirstChild("RemoteEvents")
	if remotes then
		local folder = remotes:FindFirstChild(baseCompName)
		if folder then
			return folder
		end
	end
	return error("No remote event folder under instance: " .. instance:GetFullName())
end

return Remote