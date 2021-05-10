local GroupsExtension = require(script.Parent.GroupsExtension)

return function(man)
	if man.Groups then return end
	man.Groups = GroupsExtension.new(man)
end