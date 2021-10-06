local DataEmbedded = require(script.Parent.DataEmbedded)
local DataExtension = require(script.Parent.DataExtension)

return function(man)
	if man.Data then return end
	
	local extension = DataExtension.new(man)
	man.Data = extension

	man:RegisterEmbedded({
		ClassName = "Data";
		new = function(comp)
			local data = DataEmbedded.new(extension, comp.Schema, comp.Defaults)

			-- local base = {prev = data.buffer}
			-- data.layers.base = setmetatable(base, base)
			-- data.top = base
			-- data.buffer.__index = base

			-- if not man.IsServer and comp.NetworkMode == "ServerClient" then
			-- 	local remote = {prev = base}
			-- 	data.layers.remote = setmetatable(remote, remote)
			-- 	base.__index = remote

			-- 	data.bottom = remote
			-- else
			-- 	data.bottom = base
			-- end
			
			if not man.IsServer then
				data:_rawInsert("remote", {})
			end

			data:_rawInsert("base", {})

			return data
		end;
	})
end