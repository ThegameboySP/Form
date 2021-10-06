local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local ReplicationUtils = {}

function ReplicationUtils.onReplicatedOnce(ref, callback)
	if
		ref:IsDescendantOf(ReplicatedStorage)
		or ref:IsDescendantOf(workspace)
		or ref:IsDescendantOf(ReplicatedFirst)
	then
		callback()
		return
	end

	local con
	ref.AncestryChanged:Connect(function(_, parent)
		if parent == ReplicatedStorage or parent == workspace or parent == ReplicatedFirst then
			con = callback()
		elseif (parent == nil or parent.Parent == game) and con then
			con:Disconnect()
		end
	end)

	return function()
		if con then
			con:Disconnect()
		end
	end
end

return ReplicationUtils