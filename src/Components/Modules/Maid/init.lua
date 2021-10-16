local Maid = {}
Maid.ClassName = "Maid"

local TYPE_TO_DESTRUCT_METHOD = {
	["function"] = function(task)
		return task
	end;
	["table"] = function(task)
		return task.Destroy
	end;
	["RBXScriptConnection"] = function(task)
		return task.Disconnect
	end;
	["Instance"] = function(task)
		return task.Destroy
	end;
}

function Maid.new()
	return setmetatable({
		_tasks = {};
	}, Maid)
end


function Maid.isMaid(value)
	return type(value) == "table" and value.ClassName == "Maid"
end


function Maid:__index(k)
	if Maid[k] then return Maid[k] end

	local task = self._tasks[k]
	return task and task[1] or nil
end


function Maid:__newindex(k, v)
	if v == nil then
		self:Remove(k)
	else
		self:GiveTask(v, nil, k)
	end
end


-- Cleans and clears all tasks within the maid.
function Maid:DoCleaning(...)
	local tasks = self._tasks
	local index = next(tasks)

	-- Removes all tasks from the maid. next(tbl) without the key ensures
	-- any tasks added to the maid during cleaning will be caught.
	while index ~= nil do
		self:Remove(index, ...)
		index = next(tasks)
	end
end
Maid.Destroy = Maid.DoCleaning


-- Adds a task to the maid.
-- If using id argument and it already exists, the task will be cleaned, unless the old task is equal to the new.
function Maid:GiveTask(task, destructorName, id)
	assert(destructorName == nil or type(destructorName) == "string", "Expected nil or string")
	assert(task ~= self, "Cannot add self to maid")

	local tTypeOf = typeof(task)
	local tType = type(task)
	local getDefDestruct = TYPE_TO_DESTRUCT_METHOD[tTypeOf]

	if destructorName and tType ~= "table" and tType ~= "userdata" then
		error(("Invalid type %q for a manual destructor name"):format(tType), 2)
	end

	if getDefDestruct == nil then
		error(("Gave unmaidable type %q"):format(tTypeOf), 2)
	end

	local resolvedDestruct = (destructorName == nil and getDefDestruct(task)) or (destructorName and task[destructorName])
	if resolvedDestruct == nil then
		error(("Task type %q does not have the required destruct function"):format(tTypeOf), 2)
	end

	if Maid[id] ~= nil then
		error(("%q is a reserved id"):format(tostring(id)), 2)
	end

	local tasks = self._tasks
	local oldTask = id and tasks[id]
	
	if oldTask and task == oldTask[1] then return end
	if oldTask then
		self:Remove(id)
	end

	local entry = {task, resolvedDestruct}
	id = id or entry
	tasks[id] = entry

	return id
end


-- Declarative sugar.
function Maid:Add(task, destructorName, id)
	local taskId = self:GiveTask(task, destructorName, id)
	return task, taskId
end


-- Declarative sugar. Same as :Add but destructor name is default.
function Maid:AddId(task, id)
	local taskId = self:GiveTask(task, nil, id)
	return task, taskId
end


-- Declarative sugar for adding multiple tasks in a go.
function Maid:GiveTasks(tasks)
	local ids = {}
	for key, task in next, tasks do
		if type(key) == "number" then
			ids[self:GiveTask(task)] = task
		else
			ids[self:GiveTask(task, nil, key)] = task
		end
	end

	return self, ids
end


-- Wraps the task so it will be automatically cleared from
-- internal tables when invoked.
function Maid:AddAuto(task, destructorName, id)
	local taskId
	local wrappedId

	local removed = false
	local wrapped = function(...)
		if removed then return end
		removed = true
		self:Remove(wrappedId)
		return self:Remove(taskId, ...)
	end

	taskId = self:GiveTask(task, destructorName)
	wrappedId = self:GiveTask(wrapped, nil, id)
	return wrapped, wrappedId
end


-- Removes and cleans a task from the maid.
function Maid:Remove(taskId, ...)
	local entry = self._tasks[taskId]
	if entry == nil then return end

	local task = entry[1]
	local destruct = entry[2]

	self._tasks[taskId] = nil

	if destruct == task then
		return destruct(...)
	else
		return destruct(task, ...)
	end
end
Maid.RemoveTask = Maid.Remove

return Maid