return function(instance, name, class)
	local child = instance:FindFirstChild(name)
	if child then
		return child
	end

	local newChild = Instance.new(class)
	newChild.Name = name
	newChild.Parent = instance
	
	return newChild
end