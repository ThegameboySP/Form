local CollectionService = game:GetService("CollectionService")

local ComponentsUtils = {NULL = {}}

local GROUP_PREFIX = "CompositeGroup_"
local NULL = ComponentsUtils.NULL

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


function ComponentsUtils.getTaggedInstancesFromRoot(tags, root)
	local instanceToTags = {}
	
	local descendants = root:GetDescendants()
	table.insert(descendants, root)
	for _, instance in next, descendants do
		local hasTags = {}
		instanceToTags[instance] = hasTags

		for _, tag in next, tags do
			if not CollectionService:HasTag(instance, tag) then continue end
			hasTags[tag] = true
		end
	end

	return instanceToTags
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


function ComponentsUtils.getStateFolder(instance)
	return instance:FindFirstChild("ComponentsPublic")
end


function ComponentsUtils.getOrMakeStateFolder(instance)
	local fdr = ComponentsUtils.getStateFolder(instance)
	if fdr == nil then
		fdr = Instance.new("Folder")
		fdr.Name = "ComponentsPublic"
		fdr.Archivable = false
		fdr.Parent = instance
		CollectionService:AddTag(fdr, "CompositeCrap")
	end

	return fdr
end


function ComponentsUtils.getComponentStateFolder(instance, name)
	local fdr = ComponentsUtils.getStateFolder(instance)
	
	if fdr == nil then
		return nil
	end

	local stateFdr = fdr:FindFirstChild(name)
	if stateFdr == nil then
		return nil
	end

	return stateFdr
end


function ComponentsUtils.getOrMakeComponentStateFolder(instance, name)
	local fdr = ComponentsUtils.getStateFolder(instance)
	
	if fdr == nil then
		fdr = Instance.new("Folder")
		fdr.Name = "ComponentsPublic"
		fdr.Archivable = false
		fdr.Parent = instance
		CollectionService:AddTag(fdr, "CompositeCrap")
	end

	local stateFdr = fdr:FindFirstChild(name)
	if stateFdr == nil then
		stateFdr = Instance.new("Folder")
		stateFdr.Name = name
		stateFdr.Parent = fdr
	end

	return stateFdr
end


-- TODO: test recursion and NULL
function ComponentsUtils.mergeStateValueObjects(stateFdr, deltaState)
	for key, value in next, deltaState do
		if type(value) == "table" and value ~= NULL then
			local folder = stateFdr:FindFirstChild(key)
			if folder == nil then
				folder = Instance.new("Folder")
				folder.Name = key
				folder.Parent = stateFdr
			end

			ComponentsUtils.mergeStateValueObjects(folder, value)
		elseif value == NULL then
			local prop = stateFdr:FindFirstChild(key)
			if prop then
				prop:Destroy()
			end
		else
			local prop = stateFdr:FindFirstChild(key)

			if prop and prop.ClassName ~= ComponentsUtils.getValueObjectClassNameFromType(typeof(value)) then
				CollectionService:AddTag(prop, "Replacing")
				prop:Destroy()
				prop = nil
			end

			if prop == nil then
				prop = ComponentsUtils.valueObjectFromType(typeof(value))
				prop.Name = tostring(key)
				prop.Value = value
				prop.Parent = stateFdr
			else
				prop.Value = value
			end
		end
	end
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


-- TODO: test nil
function ComponentsUtils.subscribeComponentState(stateFdr, callback)
	local connections = {}

	local function onChildAdded(property, suppressInitial)
		local lastValue
		local function onChanged(value)
			lastValue = value
			callback(property.Name, value)
		end

		table.insert(connections, property.Changed:Connect(function(value)
			if value == lastValue then return end
			onChanged(value)
		end))

		table.insert(connections, property.AncestryChanged:Connect(function(child, newParent)
			if child ~= property or newParent then return end
			if CollectionService:HasTag(property, "Replacing") then return end
			callback(property.Name, nil)
		end))

		if not suppressInitial then
			onChanged(property.Value)
		end
	end
	table.insert(connections, stateFdr.ChildAdded:Connect(onChildAdded))

	for _, property in next, stateFdr:GetChildren() do
		onChildAdded(property, true)
	end

	return function()
		for _, con in next, connections do
			con:Disconnect()
		end
	end
end


function ComponentsUtils.getComponentState(stateFdr)
	local state = {}
	for _, property in next, stateFdr:GetChildren() do
		state[property.Name] = property.Value
	end

	return state
end


function ComponentsUtils.subscribeComponentStateAnd(stateFdr, callback)
	local destruct = ComponentsUtils.subscribeComponentState(stateFdr, callback)
	for _, property in next, stateFdr:GetChildren() do
		callback(property.Name, property.Value)
	end

	return destruct
end


function ComponentsUtils.subscribeState(fdr, callback)
	local destruct = {}

	local function onChildAdded(stateFdr)
		table.insert(destruct, ComponentsUtils.subscribeComponentState(stateFdr, function(propertyName, value)
			callback(stateFdr.Name, propertyName, value)
		end))
	end

	table.insert(destruct, fdr.ChildAdded:Connect(onChildAdded))
	for _, stateFdr in next, fdr:GetChildren() do
		onChildAdded(stateFdr)
	end

	return function()
		for _, entry in next, destruct do
			local t = type(entry)
			if t == "function" then
				entry()
			elseif t == "RBXScriptConnection" then
				entry:Disconnect()
			end
		end
	end
end


function ComponentsUtils.subscribeStateAnd(fdr, callback)
	local destruct = ComponentsUtils.subscribeState(fdr, callback)
	for _, stateFdr in next, fdr:GetChildren() do
		for _, property in next, stateFdr:GetChildren() do
			callback(stateFdr.Name, property.Name, property.Value)
		end
	end
	
	return destruct
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



function ComponentsUtils.getValueObjectClassNameFromType(typeOf)
	if typeOf == "string" then
		return "StringValue"
	elseif typeOf == "number" then
		return "NumberValue"
	elseif typeOf == "boolean" then
		return "BoolValue"
	elseif typeOf == "Vector3" then
		return "Vector3Value"
	elseif typeOf == "CFrame" then
		return "CFrameValue"
	elseif typeOf == "Color3" then
		return "Color3Value"
	elseif typeOf == "Instance" then
		return "ObjectValue"
	elseif typeOf == "BrickColor" then
		return "BrickColorValue"
	end
end


function ComponentsUtils.valueObjectFromType(typeOf)
	local className = ComponentsUtils.getValueObjectClassNameFromType(typeOf)
	if className then
		return Instance.new(className)
	else
		error(("No found Value object for type of: %q"):format(typeOf))
	end
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


-- tbl1 -> tbl2
function ComponentsUtils.shallowMerge(tbl1, tbl2)
	for k, v in next, tbl1 do
		tbl2[k] = v
	end
	
	return tbl2
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