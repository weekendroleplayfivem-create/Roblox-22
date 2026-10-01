--[[
	Maid
	Tracks connections, instances, threads and cleanup callbacks so that a
	system can release everything it created in one call. Used everywhere a
	character, match or UI screen has a limited lifetime.
]]

local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

local function cleanupTask(task_: any)
	local kind = typeof(task_)
	if kind == "RBXScriptConnection" then
		task_:Disconnect()
	elseif kind == "Instance" then
		task_:Destroy()
	elseif kind == "function" then
		task_()
	elseif kind == "thread" then
		if coroutine.status(task_) ~= "dead" then
			pcall(task.cancel, task_)
		end
	elseif kind == "table" then
		if type(task_.Destroy) == "function" then
			task_:Destroy()
		elseif type(task_.Disconnect) == "function" then
			task_:Disconnect()
		end
	end
end

-- Adds a task and returns it so callers can write `local part = maid:GiveTask(Instance.new(...))`.
function Maid:GiveTask(task_: any)
	table.insert(self._tasks, task_)
	return task_
end

-- Named slots replace (and clean up) their previous value.
function Maid:Set(name: string, task_: any)
	local existing = self._tasks[name]
	if existing ~= nil and existing ~= task_ then
		cleanupTask(existing)
	end
	self._tasks[name] = task_
end

function Maid:Clear(name: string)
	self:Set(name, nil)
end

function Maid:DoCleaning()
	local tasks = self._tasks
	self._tasks = {}
	for key, task_ in tasks do
		cleanupTask(task_)
	end
end

Maid.Destroy = Maid.DoCleaning

return Maid
