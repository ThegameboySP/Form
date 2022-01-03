local LayersEmbedded = require(script.Parent.LayersEmbedded)
local LayersExtension = require(script.Parent.LayersExtension)
local Symbol = require(script.Parent.Parent.Parent.Modules.Symbol)

local PRIORITY = Symbol.named("priority")

return function(man)
	if man.Layers then return end
	
	local extension = LayersExtension.new(man)
	man.Layers = extension

	man:RegisterEmbedded({
		ClassName = "Layers";
		new = function(comp)
			if comp.Layers then
				return comp.Layers
			end
			
			local data = LayersEmbedded.new(extension, comp.Schema, comp.Defaults)
			comp.data = data.buffer
			comp:OnAlways("Destroying", function()
				data:Destroy()
			end)
			
			if not man.IsServer then
				data:_rawInsert("remote", {[PRIORITY] = 0})
			end

			data:_rawInsert("base", {[PRIORITY] = 5})

			return data
		end;
	})
end