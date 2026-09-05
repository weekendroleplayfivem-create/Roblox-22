--[[
	UIState
	Tiny cross-menu coordinator. Each menu script (Inventory, Settings, ...)
	registers its own Open/Close functions here at load time; MainMenu and
	other screens call UIState.Open/Close by name instead of reaching into
	another script's ScreenGui directly.
]]

local UIState = {}

local handlers = {}
local openMenus = {}

function UIState.Register(name, openFn, closeFn)
	handlers[name] = { Open = openFn, Close = closeFn }
end

-- Only one full-screen menu is ever open at a time, which keeps the shared
-- camera-input-lock flag each menu toggles from getting clobbered by another
-- menu closing underneath it.
function UIState.Open(name, ...)
	local handler = handlers[name]
	if not handler then
		return
	end
	for otherName in pairs(openMenus) do
		if otherName ~= name then
			UIState.Close(otherName)
		end
	end
	handler.Open(...)
	openMenus[name] = true
end

function UIState.Close(name)
	local handler = handlers[name]
	if handler then
		handler.Close()
	end
	openMenus[name] = nil
end

function UIState.Toggle(name, ...)
	if openMenus[name] then
		UIState.Close(name)
	else
		UIState.Open(name, ...)
	end
end

function UIState.CloseAll()
	for name in pairs(openMenus) do
		UIState.Close(name)
	end
end

function UIState.IsOpen(name)
	return openMenus[name] == true
end

return UIState
