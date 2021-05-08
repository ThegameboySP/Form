local CollectionService = game:GetService("CollectionService")

local ComponentsUtils = {}

local GROUP_PREFIX = "CompositeGroup_"

local function getOrMakeGroupFolder(instance)
	local folder = instance:FindFirstChild("CompositeGroups")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "CompositeGroups"
		folder.Parent = instance
	end

	return folder
end

function ComponentsUtils.getBaseComponentName(name)
	local base = name
    local prefix = base:sub(1, 2)
    if prefix == "S_" or prefix == "C_" then
        base = base:sub(3, -1) 
    end

	return base
end


function ComponentsUtils.getAncestorInstanceAttributeTag(instance, attrName)
	local currentInstance = instance

	while currentInstance do
		if currentInstance:GetAttribute(attrName) then
			return currentInstance
		end
		
		currentInstance = currentInstance.Parent
	end
end


function ComponentsUtils.getAncestorInstanceTag(instance, tagName)
	local currentInstance = instance

	while currentInstance do
		if CollectionService:HasTag(currentInstance, tagName) then
			return currentInstance
		end
		
		currentInstance = currentInstance.Parent
	end
end


function ComponentsUtils.getOrMakeConfigFolderFromInstance(instance, name)
	local configuration = instance:FindFirstChild("Configuration")
	if configuration == nil then
		configuration = Instance.new("Configuration")
		configuration.Parent = instance
		CollectionService:AddTag(configuration, "CompositeCrap")
	end

	local configFolder = configuration:FindFirstChild(name)
	if configFolder == nil then
		configFolder = Instance.new("Folder")
		configFolder.Name = name
		configFolder.Parent = configuration
	end

	return configFolder
end


function ComponentsUtils.getConfigFromInstance(instance, name)
	local config = {}
	local namespace = name .. "_"
	local namespaceLen = #namespace
	for attributeName, value in next, instance:GetAttributes() do
		if attributeName:sub(1, namespaceLen) == namespace then
			config[attributeName:sub(namespaceLen + 1, -1)] = value
		end
	end

	local configuration = instance:FindFirstChild("Configuration")
	if configuration == nil then
		return config
	end

	local configFolder = configuration:FindFirstChild(name)
	if configFolder == nil then
		return config
	end

	for _, child in next, configFolder:GetChildren() do
		if child:IsA("ValueBase") then
			config[child.Name] = child.Value
		else
			config[child.Name] = child
		end
	end

	for attributeName, value in next, configFolder:GetAttributes() do
		config[attributeName] = value
	end

	return config
end


function ComponentsUtils.updateInstanceConfig(instance, name, config)
	local currentConfig = ComponentsUtils.getConfigFromInstance(instance, name)
	for configName, value in next, currentConfig do
		if config[configName] ~= nil then continue end

		local typeOf = typeof(value)
		if typeOf == "Instance" then
			value:Destroy()
		elseif typeOf == "CFrame" then
			instance.Configuration:FindFirstChild(name):FindFirstChild(configName):Destroy()
		else
			instance:SetAttribute(configName, nil)
		end
	end

	local configFolder
	for configName, value in next, config do
		if currentConfig[configName] == value then continue end

		local typeOf = typeof(value)
		if typeOf == "Instance" then
			configFolder = configFolder or ComponentsUtils.getOrMakeConfigFolderFromInstance(instance, name)

			local clone = value:Clone()
			if clone == nil then
				clone = Instance.new("ObjectValue")
				clone.Value = value
			end
			clone.Name = configName
			clone.Parent = configFolder
		elseif typeOf == "CFrame" then
			configFolder = configFolder or ComponentsUtils.getOrMakeConfigFolderFromInstance(instance, name)

			local CFValue = Instance.new("CFrameValue")
			CFValue.Name = configName
			CFValue.Value = value
			CFValue.Parent = configFolder
		else
			instance:SetAttribute(name .. "_" .. configName, value)
		end
	end
end


function ComponentsUtils.mergeConfig(instance, name, mergeConfig)
	return ComponentsUtils.shallowMerge(
		mergeConfig or {},
		ComponentsUtils.getConfigFromInstance(instance, name)
	)
end


local function getGroupsForInstance(instance)
	local groups = {}
	
	for attributeName, value in next, instance:GetAttributes() do
		if attributeName:sub(1, #GROUP_PREFIX) == GROUP_PREFIX then
			if value ~= true then continue end
			groups[attributeName:sub(#GROUP_PREFIX + 1, -1)] = true
		end
	end

	return groups
end


function ComponentsUtils.getGroups(instance)
	local currentInstance = instance
	local currentGroups = {}
	while currentInstance do
		currentGroups = ComponentsUtils.shallowMerge(
			getGroupsForInstance(currentInstance),
			currentGroups
		)

		local folder = currentInstance:FindFirstChild("CompositeGroups")
		if folder then
			currentGroups = ComponentsUtils.shallowMerge(
				getGroupsForInstance(folder),
				currentGroups
			)
		end

		currentInstance = currentInstance.Parent
	end

	return currentGroups
end


function ComponentsUtils.updateInstanceGroups(instance, newGroups, oldGroups)
	local folder = getOrMakeGroupFolder(instance)

	for name in next, oldGroups do
		if not newGroups[name] then
			folder:SetAttribute(GROUP_PREFIX .. name, nil)
		end
	end

	for name in next, newGroups do
		if not oldGroups[name] then
			folder:SetAttribute(GROUP_PREFIX .. name, true)
		end
	end

	return newGroups
end


function ComponentsUtils.subscribeGroups(instance, callback)
	local folder = getOrMakeGroupFolder(instance)
	local con = folder.AttributeChanged:Connect(function(attrName)
		if attrName:sub(1, #GROUP_PREFIX) ~= GROUP_PREFIX then return end
		
		local isInGroup = not not folder:GetAttribute(attrName)
		callback(attrName:sub(#GROUP_PREFIX + 1, -1), isInGroup)
	end)

	return function()
		con:Disconnect()
	end
end


function ComponentsUtils.subscribeGroupsAnd(instance, callback)
	local destruct = ComponentsUtils.subscribeGroups(instance, callback)
	local folder = getOrMakeGroupFolder(instance)

	for attrName, value in next, folder:GetAttributes() do
		if attrName:sub(1, #GROUP_PREFIX) ~= GROUP_PREFIX then continue end

		local isInGroup = not not value
		callback(attrName:sub(#GROUP_PREFIX + 1, -1), isInGroup)
	end

	return destruct
end


function ComponentsUtils.removeCompositeMutation(instance)
	local folder = instance:FindFirstChild("CompositeGroups")
	if folder then
		folder:Destroy()
	end
end


function ComponentsUtils.shallowCopy(tbl)
	local newTbl = {}
	for k, v in next, tbl do
		newTbl[k] = v
	end

	return newTbl
end


function ComponentsUtils.union(...)
	local to = {}

	for _, from in ipairs({...}) do
		for k, v in pairs(from) do
			to[k] = v
		end
	end

	return to
end


-- tbl1 -> tbl2
function ComponentsUtils.shallowMerge(tbl1, tbl2)
	local c = ComponentsUtils.shallowCopy(tbl2)
	for k, v in next, tbl1 do
		c[k] = v
	end
	
	return c
end


-- tbl1 -> tbl2
function ComponentsUtils.deepMerge(tbl1, tbl2)
	local c = ComponentsUtils.deepCopy(tbl2)

	for k, v in next, tbl1 do
		if type(v) == "table" then
			local ct = type(c[k]) == "table" and c[k] or {}
			c[k] = ComponentsUtils.deepMerge(v, ct)
		else
			c[k] = v
		end
	end

	return c
end


-- Assumes non-table keys.
function ComponentsUtils.deepCopy(t)
	local nt = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			nt[k] = ComponentsUtils.deepCopy(v)
		else
			nt[k] = v
		end
	end

	return nt
end


function ComponentsUtils.diff(new, old)
	local delta = {}

	for k, v in pairs(new) do
		local ov = old[k]

		if type(v) == "table" and type(ov) == "table" then
			local subDelta = ComponentsUtils.diff(v, ov)
			if next(subDelta) then
				delta[k] = subDelta
			end
		elseif v ~= ov then
			delta[k] = v
		end
	end

	return delta
end


function ComponentsUtils.shallowCompare(tbl1, tbl2)
	for k, v in next, tbl1 do
		if tbl2[k] ~= v then
			return false
		end
	end

	for k, v in next, tbl2 do
		if tbl1[k] ~= v then
			return false
		end
	end

	return true
end


function ComponentsUtils.isInTable(tbl, value)
	for _, v in next, tbl do
		if v == value then
			return true
		end
	end

	return false
end


function ComponentsUtils.arrayToHash(array)
	local hash = {}
	for _, value in next, array do
		hash[value] = true
	end

	return hash
end


function ComponentsUtils.hashToArray(hash)
	local array = {}
	local len = 0
	for item in next, hash do
		len += 1
		array[len] = item
	end

	return array
end


function ComponentsUtils.indexTableOrError(name, tbl)
	return setmetatable(tbl, {__index = function(_, k)
		error(("%s is not a valid member of %q"):format(k, name), 2)
	end})
end

return ComponentsUtils