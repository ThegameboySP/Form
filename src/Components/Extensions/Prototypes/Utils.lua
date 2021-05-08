local CollectionService = game:GetService("CollectionService")

local ComponentsUtils = require(script.Parent.Parent.Parent.Shared.ComponentsUtils)

local Utils = {}

local GROUP_PREFIX = "CompositeGroup_"

local function makePrototype(instance, parent, hasTags, groups)
	return {
		cloneActive = false;
		instance = instance;
		parent = parent;
		hasTags = hasTags;
		groups = groups;
		ancestorPrototype = nil;
	}
end

local function getGroups(instance)
	local instanceGroups = Utils.getGroups(instance)
	if next(instanceGroups) == nil then
		instanceGroups = {Default = true}
	end

	return instanceGroups
end

function Utils.generatePrototypesFromRoot(tags, root, groups)
	local prototypes = {}

	for instance, hasTags in pairs(Utils.getTaggedInstancesFromRoot(tags, root)) do
		if next(hasTags) == nil then continue end
		local prototypeGroups = getGroups(instance)
		for group in pairs(groups) do
			prototypeGroups[group] = true
		end

		prototypes[instance] = makePrototype(instance, instance.Parent, hasTags, prototypeGroups)
	end

	return prototypes
end

function Utils.getTaggedInstancesFromRoot(tags, root)
	local instanceToTags = {}
	
	local instances = root:GetDescendants()
	table.insert(instances, root)

	for _, instance in pairs(instances) do
		local hasTags = {}
		instanceToTags[instance] = hasTags

		for _, tag in pairs(tags) do
			if not CollectionService:HasTag(instance, tag) then continue end
			hasTags[tag] = true
		end
	end

	return instanceToTags
end

local function getGroupsForInstance(instance)
	local groups = {}
	
	for attributeName, value in pairs(instance:GetAttributes()) do
		if attributeName:sub(1, #GROUP_PREFIX) == GROUP_PREFIX then
			if value ~= true then continue end
			groups[attributeName:sub(#GROUP_PREFIX + 1, -1)] = true
		end
	end

	return groups
end


function Utils.getGroups(instance)
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

function Utils.findFirstAncestorInDict(instance, dict)
	local current = instance

	while current do
		local found = dict[current]
		if found then
			return found
		end

		current = current.Parent
	end

	return nil
end

function Utils.getOrMakeConfigFolderFromInstance(instance, name)
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


function Utils.getConfigFromInstance(instance, name)
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


function Utils.updateInstanceConfig(instance, name, config)
	local currentConfig = Utils.getConfigFromInstance(instance, name)
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
			configFolder = configFolder or Utils.getOrMakeConfigFolderFromInstance(instance, name)

			local clone = value:Clone()
			if clone == nil then
				clone = Instance.new("ObjectValue")
				clone.Value = value
			end
			clone.Name = configName
			clone.Parent = configFolder
		elseif typeOf == "CFrame" then
			configFolder = configFolder or Utils.getOrMakeConfigFolderFromInstance(instance, name)

			local CFValue = Instance.new("CFrameValue")
			CFValue.Name = configName
			CFValue.Value = value
			CFValue.Parent = configFolder
		else
			instance:SetAttribute(name .. "_" .. configName, value)
		end
	end
end

return Utils