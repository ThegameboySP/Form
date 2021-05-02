local CollectionService = game:GetService("CollectionService")

local Maid = require(script.Parent.Parent.Parent.Modules.Maid)
local Symbol = require(script.Parent.Parent.Parent.Modules.Symbol)

local StateInterfacer = {}
local NULL = Symbol.named("null")
StateInterfacer.NULL = NULL

local typeOfToValueBase = {
	Instance = true;
	CFrame = true;
	Ray = true;
}

function StateInterfacer.getValueObjectClassNameFromType(typeOf)
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
	elseif typeOf == "Ray" then
		return "RayValue"
	end
end


function StateInterfacer.valueObjectFromType(typeOf)
	local className = StateInterfacer.getValueObjectClassNameFromType(typeOf)
	if className then
		return Instance.new(className)
	else
		error(("No found Value object for type of: %q"):format(typeOf))
	end
end


function StateInterfacer.mergeStateValueObjects(stateFdr, deltaState)
	for key, value in next, deltaState do
		assert(type(key) == "string", "Expected 'string' as key")
		local typeOf = typeof(value)

		if typeOf == "table" and value ~= NULL then
			local folder = stateFdr:FindFirstChild(key)
			if folder == nil then
				folder = Instance.new("Folder")
				folder.Name = key
				folder.Parent = stateFdr
			end

			StateInterfacer.mergeStateValueObjects(folder, value)
		elseif value == NULL then
			local prop = stateFdr:FindFirstChild(key)
			if prop then
				prop:Destroy()
			else
				stateFdr:SetAttribute(key, nil)
			end
		elseif typeOfToValueBase[typeOf] then
			stateFdr:SetAttribute(key, false)
			local prop = stateFdr:FindFirstChild(key)

			if prop and prop.ClassName ~= StateInterfacer.getValueObjectClassNameFromType(typeof(value)) then
				prop:Destroy()
				prop = nil
			end

			if prop == nil then
				prop = StateInterfacer.valueObjectFromType(typeof(value))
				prop.Name = key
				prop.Value = value
				prop.Parent = stateFdr
			else
				prop.Value = value
			end
		else
			local prop = stateFdr:FindFirstChild(key)
			if prop then
				prop:Destroy()
			end

			stateFdr:SetAttribute(key, value)
		end
	end

	-- Signal a full update has been made.
	stateFdr:SetAttribute("__flush", not stateFdr:GetAttribute("__flush"))
end

local function subscribeComponentStateImmediate(stateFdr, path, callback, flush)
	path = path or ""
	local maid = Maid.new()

	local function onChildAdded(child, suppressInitial)
		local currentPath = path == "" and child.Name or path .. "." .. child.Name
		local childMaid = maid:AddId(Maid.new(), child)

		if child:IsA("Folder") then
			childMaid:Add(child.ChildAdded:Connect(function(child2)
				local child2Maid = childMaid:AddId(Maid.new(), child2)
				local child2Path = currentPath .. "." .. child2.Name
				child2Maid:Add(subscribeComponentStateImmediate(child2, callback, child2Path))

				-- TODO: test if table fires after all its descendants have been called.
				-- This generates a new table to describe its descendant state, which only works
				-- if you don't expect the table identity to hold.
				child2Maid:Add(child2:GetAttributeChangedSignal("__flush"):Connect(function()
					flush(false)
				end))
			end))

			childMaid:Add(child.ChildRemoved:Connect(function(thisChild)
				childMaid:Remove(thisChild)
			end))

			return
		end

		local lastValue
		local function onChanged(value)
			lastValue = value
			callback(currentPath, value)
		end

		childMaid:Add(child.Changed:Connect(function(value)
			-- Currently, Roblox will still replicate an update to a property that since reverted to its old value.
			if value == lastValue then return end
			onChanged(value)
		end))

		childMaid:Add(child.AncestryChanged:Connect(function(thisChild, newParent)
			if thisChild ~= child or newParent then return end

			maid:Remove(childMaid)
			callback(currentPath, nil)
		end))

		if not suppressInitial then
			onChanged(child.Value)
		end
	end

	maid:Add(stateFdr.ChildAdded:Connect(onChildAdded))
	for _, property in next, stateFdr:GetChildren() do
		onChildAdded(property, true)
	end
	flush(true)

	local function onAttributeChanged(attrName)
		if attrName == "__flush" then return end

		local value = stateFdr:GetAttribute(attrName)
		callback(attrName, value)
	end
	maid:Add(stateFdr.AttributeChanged:Connect(onAttributeChanged))
	
	return function()
		maid:DoCleaning()
	end
end

function StateInterfacer.subscribeComponentState(stateFdr, callback)
	local calls = {}
	local f = subscribeComponentStateImmediate(stateFdr, function(path, value)
		table.insert(calls, {path, value})
	end)

	-- __flush is changed once to signal that a full update to the state has been made.
	local con = stateFdr:GetAttributeChangedSignal("__flush"):Connect(function()
		for key, call in next, calls do
			calls[key] = nil
			callback(call[1], call[2])
		end
	end)

	return function()
		f()
		con:Disconnect()
	end
end


function StateInterfacer.getComponentState(stateFdr, state)
	state = state or {}

	for _, child in next, stateFdr:GetChildren() do
		if child:IsA("Folder") then
			local newState = {}
			state[child.Name] = newState
			StateInterfacer.getComponentState(child, newState)
		else
			state[child.Name] = child.Value
		end
	end

	for attrName, value in next, stateFdr:GetAttributes() do
		state[attrName] = value
	end

	return state
end


function StateInterfacer.subscribeComponentStateAnd(stateFdr, callback)
	local destruct = StateInterfacer.subscribeComponentState(stateFdr, callback)

	local function fireCallback(tbl, path)
		for name, value in next, tbl do
			local currentPath = (path == "" and "" or path .. ".") .. name
			if type(value) == "table" then
				fireCallback(value, currentPath)
			else
				callback(currentPath, value)
			end
		end
	end
	fireCallback(StateInterfacer.getComponentState(stateFdr), "")

	return destruct
end


function StateInterfacer.subscribeState(fdr, callback)
	local maid = Maid.new()

	local function onChildAdded(stateFdr)
		local childMaid = maid:AddId(Maid.new(), stateFdr)
		childMaid:Add(StateInterfacer.subscribeComponentState(stateFdr, function(propertyName, value)
			callback(stateFdr.Name, propertyName, value)
		end))
	end

	maid:Add(fdr.ChildAdded:Connect(onChildAdded))
	for _, stateFdr in next, fdr:GetChildren() do
		onChildAdded(stateFdr)
	end

	return function()
		maid:DoCleaning()
	end
end


function StateInterfacer.subscribeStateAnd(fdr, callback)
	local maid = Maid.new()

	local function onChildAdded(stateFdr)
		local childMaid = maid:AddId(Maid.new(), stateFdr)
		childMaid:Add(StateInterfacer.subscribeComponentStateAnd(stateFdr, function(propertyName, value)
			callback(stateFdr.Name, propertyName, value)
		end))
	end

	maid:Add(fdr.ChildAdded:Connect(onChildAdded))
	for _, stateFdr in next, fdr:GetChildren() do
		onChildAdded(stateFdr)
	end

	return function()
		maid:DoCleaning()
	end
end


function StateInterfacer.getStateFolder(instance)
	return instance:FindFirstChild("ComponentsPublic")
end


function StateInterfacer.getOrMakeStateFolder(instance)
	local fdr = StateInterfacer.getStateFolder(instance)
	if fdr == nil then
		fdr = Instance.new("Folder")
		fdr.Name = "ComponentsPublic"
		fdr.Archivable = false
		fdr.Parent = instance
		CollectionService:AddTag(fdr, "CompositeCrap")
	end

	return fdr
end


function StateInterfacer.getComponentStateFolder(instance, name)
	local fdr = StateInterfacer.getStateFolder(instance)
	
	if fdr == nil then
		return nil
	end

	local stateFdr = fdr:FindFirstChild(name)
	if stateFdr == nil then
		return nil
	end

	return stateFdr
end


function StateInterfacer.getOrMakeComponentStateFolder(instance, name)
	local fdr = StateInterfacer.getStateFolder(instance)
	
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

return StateInterfacer