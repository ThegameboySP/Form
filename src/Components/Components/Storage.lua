local BaseComponent = require(script.Parent.Parent.Composite.BaseComponent)
local Storage = BaseComponent:extend("Storage")

function Storage.mapState(config, state)
	return Storage.util.assign(state, config)
end

return Storage