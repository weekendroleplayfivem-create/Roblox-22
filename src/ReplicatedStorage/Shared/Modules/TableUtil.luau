--[[
	TableUtil
	Pure table helpers. `Reconcile` is used by the data system to add missing
	keys from default data without overwriting saved values.
]]

local TableUtil = {}

function TableUtil.DeepCopy<T>(source: T): T
	if type(source) ~= "table" then
		return source
	end
	local copy = {}
	for key, value in source :: any do
		copy[TableUtil.DeepCopy(key)] = TableUtil.DeepCopy(value)
	end
	return (copy :: any) :: T
end

-- Fills missing keys in `target` from `template` (recursively). Keys with the
-- wrong type are replaced with the template value.
function TableUtil.Reconcile(target: { [any]: any }, template: { [any]: any }): { [any]: any }
	for key, defaultValue in template do
		local current = target[key]
		if current == nil then
			target[key] = TableUtil.DeepCopy(defaultValue)
		elseif type(defaultValue) == "table" then
			if type(current) ~= "table" then
				target[key] = TableUtil.DeepCopy(defaultValue)
			else
				TableUtil.Reconcile(current, defaultValue)
			end
		elseif type(current) ~= type(defaultValue) then
			target[key] = defaultValue
		end
	end
	return target
end

function TableUtil.Count(source: { [any]: any }): number
	local count = 0
	for _ in source do
		count += 1
	end
	return count
end

function TableUtil.Keys(source: { [any]: any }): { any }
	local keys = {}
	for key in source do
		table.insert(keys, key)
	end
	return keys
end

function TableUtil.Shuffle<T>(list: { T }, rng: Random?): { T }
	local random = rng or Random.new()
	for index = #list, 2, -1 do
		local swap = random:NextInteger(1, index)
		list[index], list[swap] = list[swap], list[index]
	end
	return list
end

function TableUtil.Filter<T>(list: { T }, predicate: (T) -> boolean): { T }
	local result = {}
	for _, value in list do
		if predicate(value) then
			table.insert(result, value)
		end
	end
	return result
end

function TableUtil.Map<T, U>(list: { T }, mapper: (T) -> U): { U }
	local result = {}
	for index, value in list do
		result[index] = mapper(value)
	end
	return result
end

function TableUtil.DeepFreeze<T>(source: T): T
	if type(source) == "table" and not table.isfrozen(source :: any) then
		for _, value in source :: any do
			TableUtil.DeepFreeze(value)
		end
		table.freeze(source :: any)
	end
	return source
end

return TableUtil
