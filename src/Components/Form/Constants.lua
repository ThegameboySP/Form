local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[[
	This is weird but it's so that the None symbol replicates cleanly without having
	to traverse the entire table.
]]

local None
if RunService:IsServer() then
	None = Instance.new("Folder")
	None.Name = "Form_None"
	if RunService:IsRunning() then
		None.Parent = ReplicatedStorage
	end
else
	None = ReplicatedStorage:WaitForChild("Form_None")
end

return {
	None = None;
}