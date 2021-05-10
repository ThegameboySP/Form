local BaseComponent = require(script.Parent.Parent.Parent.Composite.BaseComponent)
local GroupsComponent = BaseComponent:extend("GroupsComponent")

function GroupsComponent.mapState(config)
	return config
end

return GroupsComponent