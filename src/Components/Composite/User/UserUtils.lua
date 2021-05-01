local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local UserUtils = {}
local EMPTY_TABLE = {}

local getters = {
	children = function(instance)
		return instance:GetChildren()
	end;
	descendants = function(instance)
		return instance:GetDescendants()
	end;
	ancestors = function(instance)
		local ancestors = {}
		local current = instance
		while current.Parent do
			local parent = current.Parent
			table.insert(ancestors, parent)
			current = parent
		end

		return ancestors
	end;
}

local filters = {
	hasComponent = function(instance, compName)
		return (not not instance:GetAttribute("CompositeClone"))
			and CollectionService:HasTag(instance, compName)
	end;
	hasAComponent = function(instance)
		return not not instance:GetAttribute("CompositeClone")
	end;
	hasTag = function(instance, tag)
		return CollectionService:HasTag(instance, tag)
	end;
	isA = function(instance, className)
		return instance:IsA(className)
	end;
	hasProperty = function(instance, name, value)
		return instance[name] == value
	end;
}

local function getFiltered(getter, filter, instance, ...)
	local instances = getter(instance)
	local filtered = {}
	for _, instance2 in ipairs(instances) do
		if not filter(instance2, ...) then continue end
		table.insert(filtered, instance2)
	end

	return filtered
end

function UserUtils.getComponentChildren(instance, compName)
	if compName ~= nil then
		return getFiltered(getters.children, filters.hasComponent, instance, compName)
	else
		return getFiltered(getters.children, filters.hasAComponent, instance)
	end
end


function UserUtils.findFirstComponent(instance, compName)
	return getFiltered(getters.children, filters.hasComponent, instance, compName)[1]
end


function UserUtils.hasComponent(instance, compName)
	return filters.hasComponent(instance, compName)
end


function UserUtils.get(instance)
	return setmetatable(EMPTY_TABLE, {__index = function(_, getterName)
		local getter = getters[getterName]

		return setmetatable(EMPTY_TABLE, {__index = function(_, filterName)
			return function(...)
				local filter = filters[filterName]
				local filtered = getFiltered(getter, filter, instance, ...)
				
				if filter(instance, ...) then
					table.insert(filtered, instance)
				end
				return filtered
			end
		end, _call = function()
			local instances = getter(instance)
			table.insert(instances, instance)
			return instances
		end})
	end})
end


function UserUtils.findFirst(instance)
	return setmetatable(EMPTY_TABLE, {__index = function(_, getterName)
		local getter = getters[getterName]

		return setmetatable(EMPTY_TABLE, {__index = function(_, filterName)
			return function(...)
				local filter = filters[filterName]
				if filter(instance, ...) then
					return instance
				end

				local filtered = getFiltered(getter, filter, instance, ...)
				return filtered[1]
			end
		end, _call = function()
			local instances = getter(instance)
			return instances[1]
		end})
	end})
end


function UserUtils.getPlayer(part)
	local char = UserUtils.getCharacter(part)
	if char == nil then return end
	return Players:GetPlayerFromCharacter(part.Parent)
end



function UserUtils.getCharacter(part)
	local hum = part.Parent and part.Parent:FindFirstChild("Humanoid")
	if not hum then return end
	return part.Parent
end


function UserUtils.isValidCharacter(character)
	if not character:FindFirstChild("Humanoid") then return false end
	if character.Humanoid:GetState() == Enum.HumanoidStateType.Dead then return false end
	if not character:FindFirstChild("Head") then return false end

	return true
end


function UserUtils.findCharacterAncestor(part)
	local lastDescendant = part
	local humanoid
	repeat
		local model = lastDescendant:FindFirstAncestorOfClass("Model")
		if not model then break end

		humanoid = model:FindFirstChildOfClass("Humanoid")
		lastDescendant = model
	until humanoid
	
	return humanoid and humanoid.Parent or nil
end


function UserUtils.getPlayerFromConnectedParts(part)
	local character
	for _, connected in next, part:GetConnectedParts() do
		character = UserUtils.findCharacterAncestor(connected)
		if character then break end
	end

	if not character then return end
	return Players:GetPlayerFromCharacter(character)
end


function UserUtils.weld(p0, p1)
	local weld = Instance.new("Weld")
	weld.Part0 = p0
	weld.Part1 = p1
	weld.C0 = p0.CFrame:inverse() * p1.CFrame
	weld.Parent = p1

	return weld
end


function UserUtils.makeTranslationHandle(children)
	local offsets = {}
	for _, child in ipairs(children) do
		offsets[child] = child.CFrame
	end

	local currentCF = CFrame.new()
	return {
		MoveTo = function(self, CF)
			currentCF = CF
			for child, offset in next, offsets do
				child.CFrame = offset * CF
			end
		end;

		GetCFrame = function(self)
			return currentCF
		end;
	}
end

return UserUtils