local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local UserUtils = {}

local getters = {
	children = function(instance)
		return instance:GetChildren()
	end
}

local filters = {
	hasComponent = function(instance, compName)
		return CollectionService:HasTag(instance, "CompositeInstance")
			and CollectionService:HasTag(instance, compName)
	end;
	hasAComponent = function(instance)
		return CollectionService:HasTag(instance, "CompositeInstance")
	end
}

local function getFiltered(getter, filter, instance, ...)
	local instances = getter(instance)
	local filtered = {}
	for _, instance2 in next, instances do
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


function UserUtils.getPlayer(part)
	local hum = part.Parent and part.Parent:FindFirstChild("Humanoid")
	if not hum then return end

	return Players:GetPlayerFromCharacter(part.Parent)
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

return UserUtils