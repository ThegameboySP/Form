local BaseComponent = require(script.Parent.Parent.Parent.Composite.BaseComponent)
local ComponentsUtils = require(script.Parent.Parent.Parent.Shared.ComponentsUtils)
local GroupsComponent = BaseComponent:extend("GroupsComponent")

function GroupsComponent.mapState(config, state)
	local dict = ComponentsUtils.union({}, state)

	for _, groupName in pairs(config) do
		dict[groupName] = true
	end

	return dict
end

return GroupsComponent