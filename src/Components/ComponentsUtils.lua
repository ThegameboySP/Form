local CollectionService = game:GetService("CollectionService")

local ComponentsUtils = {}

local GROUP_PREFIX = "CompositeGroup_"

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
		if CollectionService:HasTag(instance, tagName) then
			return currentInstance
		end
		
		currentInstance = currentInstance.Parent
	end
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


function ComponentsUtils.getGroupsFolder(instance)
	local configuration = instance:FindFirstChild("Configuration")
	if configuration == nil then
		return nil
	end

	local groupsFolder = configuration:FindFirstChild("Groups")
	return groupsFolder
end


local function getGroupsForInstance(instance)
	local groups = {}
	
	for attributeName, value in next, instance:GetAttributes() do
		if attributeName:sub(1, #GROUP_PREFIX) == GROUP_PREFIX then
			if value ~= true then return end
			groups[attributeName:sub(16, -1)] = true
		end
	end

	local groupsFolder = ComponentsUtils.getGroupsFolder(instance)
	if groupsFolder == nil then
		return groups
	end

	for _, child in next, groupsFolder:GetChildren() do
		if child.Value ~= true then continue end
		groups[child.Name] = true
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
	end

	local stateFdr = fdr:FindFirstChild(name)
	if stateFdr == nil then
		stateFdr = Instance.new("Folder")
		stateFdr.Name = name
		stateFdr.Parent = fdr
	end

	return stateFdr
end


function ComponentsUtils.mergeStateValueObjects(stateFdr, deltaState)
	for key, value in next, deltaState do
		local prop = stateFdr:FindFirstChild(key)

		if prop and prop.ClassName ~= ComponentsUtils.getValueObjectClassNameFromType(typeof(value)) then
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


function ComponentsUtils.updateInstanceGroups(instance, newGroups, oldGroups)
	for name in next, oldGroups do
		if not newGroups[name] then
			instance:SetAttribute(GROUP_PREFIX .. name, nil)
		end
	end

	for name in next, newGroups do
		if not oldGroups[name] then
			instance:SetAttribute(GROUP_PREFIX .. name, true)
		end
	end

	return newGroups
end


-- This shouldn't leak memory.
-- Once a value object or state folder is deparented, there will no longer be any strong
-- references here to it (thanks to .Changed), nor should there be in the callback,
-- as long as the destruct function isn't kept around.
function ComponentsUtils.subscribeComponentState(stateFdr, callback)
	local connections = {}

	table.insert(connections, stateFdr.ChildAdded:Connect(function(property)
		local function onChanged(value)
			callback(property.Name, value)
		end

		table.insert(connections, property.Changed:Connect(onChanged))
		onChanged(property.Value)
	end))

	for _, property in next, stateFdr:GetChildren() do
		table.insert(connections, property.Changed:Connect(function(value)
			callback(property.Name, value)
		end))
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
	local con = instance.AttributeChanged:Connect(function(attrName)
		if attrName:sub(1, #GROUP_PREFIX) ~= GROUP_PREFIX then return end
		
		local isInGroup = not not instance:GetAttribute(attrName)
		callback(attrName:sub(#GROUP_PREFIX + 1, -1), isInGroup)
	end)

	return function()
		con:Disconnect()
	end
end


function ComponentsUtils.subscribeGroupsAnd(instance, callback)
	local destruct = ComponentsUtils.subscribeGroups(instance, callback)
	for attrName, value in next, instance:GetAttributes() do
		if attrName:sub(1, #GROUP_PREFIX) ~= GROUP_PREFIX then return end

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


function ComponentsUtils.indexTableOrError(name, tbl)
	return setmetatable(tbl, {__index = function(_, k)
		error(("%s is not a valid member of %q"):format(k, name), 2)
	end})
end

return ComponentsUtils