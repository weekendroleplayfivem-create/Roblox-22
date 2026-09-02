--!nonstrict
--[[
	Trove.luau
	Cleanup bag. Everything a controller creates goes in a trove so character
	respawns can't leak connections, instances or bound actions.
--]]

local Trove = {}
Trove.__index = Trove

function Trove.new()
	return setmetatable({ _objects = {} }, Trove)
end

function Trove:Add(object, cleanupMethod: string?)
	table.insert(self._objects, { object = object, method = cleanupMethod })
	return object
end

function Trove:Connect(signal, handler)
	return self:Add(signal:Connect(handler))
end

function Trove:Fn(callback: () -> ())
	return self:Add(callback)
end

local function cleanupOne(object, method: string?)
	if method then
		object[method](object)
	elseif typeof(object) == "Instance" then
		object:Destroy()
	elseif typeof(object) == "RBXScriptConnection" then
		object:Disconnect()
	elseif typeof(object) == "function" then
		object()
	elseif type(object) == "table" then
		if object.Disconnect then
			object:Disconnect()
		elseif object.Destroy then
			object:Destroy()
		end
	end
end

function Trove:Remove(object)
	for index, entry in self._objects do
		if entry.object == object then
			table.remove(self._objects, index)
			cleanupOne(entry.object, entry.method)
			return true
		end
	end
	return false
end

function Trove:Clean()
	local objects = self._objects
	self._objects = {}
	-- Reverse order: dependants are cleaned before their dependencies.
	for index = #objects, 1, -1 do
		local entry = objects[index]
		local ok, err = pcall(cleanupOne, entry.object, entry.method)
		if not ok then
			warn(`[Trove] cleanup error: {err}`)
		end
	end
end

Trove.Destroy = Trove.Clean

return Trove
