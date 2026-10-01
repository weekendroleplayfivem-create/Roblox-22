--[[
	ObjectPool
	Re-uses short-lived instances (tracers, impact rings, sparks) instead of
	creating and destroying hundreds of parts per second.
]]

local ObjectPool = {}
ObjectPool.__index = ObjectPool

local HIDDEN_CFRAME = CFrame.new(0, -10000, 0)

function ObjectPool.new(factory: () -> BasePart, parent: Instance, maxSize: number?)
	return setmetatable({
		_factory = factory,
		_parent = parent,
		_free = {},
		_maxSize = maxSize or 64,
	}, ObjectPool)
end

function ObjectPool:Get(): BasePart
	local object = table.remove(self._free)
	if not object or not object.Parent then
		object = self._factory()
		object.Parent = self._parent
	end
	return object
end

function ObjectPool:Return(object: BasePart)
	if #self._free >= self._maxSize then
		object:Destroy()
		return
	end
	object.CFrame = HIDDEN_CFRAME
	table.insert(self._free, object)
end

-- Returns the object to the pool after `delay` seconds.
function ObjectPool:ReturnAfter(object: BasePart, delay: number)
	task.delay(delay, function()
		self:Return(object)
	end)
end

function ObjectPool:Destroy()
	for _, object in self._free do
		object:Destroy()
	end
	table.clear(self._free)
end

return ObjectPool
