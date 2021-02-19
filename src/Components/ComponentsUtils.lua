local ComponentsUtils = {}

function ComponentsUtils.getPropsFromInstance(instance, name)
	local props = {}
	local configuration = instance:FindFirstChild("Configuration")
	if configuration == nil then
		return props
	end

	local configFolder = configuration:FindFirstChild(name)
	if configFolder == nil then
		return props
	end

	for _, child in next, configFolder:GetChildren() do
		if child:IsA("ValueBase") then
			props[child.Name] = child.Value
		else
			props[child.Name] = child
		end
	end

	return props
end


function ComponentsUtils.mergeProps(instance, name, mergeProps)
	return ComponentsUtils.shallowMerge(
		mergeProps or {},
		ComponentsUtils.getPropsFromInstance(instance, name)
	)
end


function ComponentsUtils.getGroupsFolderFromInstance(instance)
	local configuration = instance:FindFirstChild("Configuration")
	if configuration == nil then
		return nil
	end

	local groupsFolder = configuration:FindFirstChild("Groups")
	return groupsFolder
end


function ComponentsUtils.getOrMakeGroupsFolderFromInstance(instance)
	local configuration = instance:FindFirstChild("Configuration")
	if configuration == nil then
		configuration = Instance.new("Configuration")
		configuration.Parent = instance
	end

	local groupsFolder = configuration:FindFirstChild("Groups")
	if groupsFolder == nil then
		groupsFolder = Instance.new("Folder")
		groupsFolder.Name = "Groups"
		groupsFolder.Parent = configuration
	end

	return groupsFolder
end


function ComponentsUtils.getGroupsFromInstance(instance)
	local groups = {}
	local groupsFolder = ComponentsUtils.getGroupsFolderFromInstance(instance)
	if groupsFolder == nil then
		return {}
	end

	for _, child in next, groupsFolder:GetChildren() do
		if child.Value ~= true then continue end
		groups[child.Name] = true
	end

	return groups
end


function ComponentsUtils.mergeGroups(instance, mergeGroups)
	return ComponentsUtils.shallowMerge(
		mergeGroups or {},
		ComponentsUtils.getGroupsFromInstance(instance)
	)
end


function ComponentsUtils.getOrMakeStateFolder(instance, name)
	local fdr = instance:FindFirstChild("ComponentsPublic")
	
	if fdr == nil then
		fdr = Instance.new("Folder")
		fdr.Name = "ComponentsPublic"
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

		if prop and not prop.ClassName:lower():find( typeof(value):lower() ) then
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


function ComponentsUtils.updateGroupValueObjects(instance, newGroups, oldGroups)
	local groupsFolder = ComponentsUtils.getOrMakeGroupsFolderFromInstance(instance)

	for name in next, oldGroups do
		if not newGroups[name] then
			local group = groupsFolder:FindFirstChild(name)
			if group == nil then
				warn(("Group %q was not found under %q!"):format(name, instance:GetFullName()))
				continue
			end

			group:Destroy()
		end
	end

	for name in next, newGroups do
		-- Look for a group entry in instance, for compatibility with external insertion of groups.
		if not oldGroups[name] and groupsFolder:FindFirstChild(name) == nil then
			local bool = Instance.new("BoolValue")
			bool.Name = name
			bool.Value = true
			bool.Parent = groupsFolder
		end
	end

	return newGroups
end


-- This shouldn't leak memory.
-- Once a value object or state folder is deparented, there will no longer be any strong
-- references here to it (thanks to .Changed), nor should there be in the callback.
function ComponentsUtils.subscribeState(stateFdr, callback)
	local function onChildAdded(property)
		local function onChanged(value)
			callback(property, value)
		end

		property.Changed:Connect(onChanged)
		onChanged(property.Value)
	end

	stateFdr.ChildAdded:Connect(onChildAdded)
	for _, property in next, stateFdr:GetChildren() do
		onChildAdded(property)
	end
end


function ComponentsUtils.subscribeGroups(instance, callback)
	local groupFolder = ComponentsUtils.getGroupsFolderFromInstance(instance)
	local function onChildAdded(group)
		print("childadded", group)
		local function onAncestryChanged(thisChild, newParent)
			if newParent then return end
			callback(thisChild, false)
		end

		group.AncestryChanged:Connect(onAncestryChanged)
		callback(group, true)
	end

	instance.Parent = game.ReplicatedStorage

	groupFolder.ChildAdded:Connect(onChildAdded)
	for _, group in next, groupFolder:GetChildren() do
		onChildAdded(group)
	end
end


function ComponentsUtils.valueObjectFromType(typeOf)
	if typeOf == "string" then
		return Instance.new("StringValue")
	elseif typeOf == "number" then
		return Instance.new("NumberValue")
	elseif typeOf == "bool" then
		return Instance.new("BoolValue")
	elseif typeOf == "Vector3" then
		return Instance.new("Vector3Value")
	elseif typeOf == "CFrame" then
		return Instance.new("CFrameValue")
	elseif typeOf == "Color3" then
		return Instance.new("Color3Value")
	else
		error(("No found Value object for type of: %q"):format(typeOf))
	end
end


function ComponentsUtils.searchInstance(instance, ...)
	if instance == nil then
		return nil
	end

	local current = instance

	for _, childName in next, {...} do
		current = current:FindFirstChild(childName)
		if not current then
			return nil
		end
	end

	return current
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


function ComponentsUtils.indexTableOrError(name, tbl)
	return setmetatable(tbl, {__index = function(_, k)
		error(("%s is not a valid member of %q"):format(k, name), 2)
	end})
end


function ComponentsUtils.sortHierarchy()

end


-- Descendants first.
-- To be used for figuring out when to call the constructor / Main depending on hierarchy order.
function ComponentsUtils.flattenInstanceTree(tree)

end

return ComponentsUtils