local DataEmbedded = require(script.Parent.DataEmbedded)
local DataExtension = require(script.Parent.DataExtension)
local Symbol = require(script.Parent.Parent.Parent.Modules.Symbol)

local PRIORITY = Symbol.named("priority")

return function(man)
	if man.Data then return end
	
	local extension = DataExtension.new(man)
	man.Data = extension

	man:RegisterEmbedded({
		ClassName = "Data";
		new = function(comp)
			if comp.Data then
				return comp.Data
			end
			
			local data = DataEmbedded.new(extension, comp.Schema, comp.Defaults)
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