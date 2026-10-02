--[[
	ClientMain
	Boots every client controller: Init (wire up, no yielding) for all, then
	Start for all. Order matters only for Init-time dependencies.
]]

local Controllers = script.Parent:WaitForChild("Controllers")

local ORDER = {
	"ClientState",
	"SoundController",
	"InputController",
	"CameraController",
	"EffectsController",
	"MovementController",
	"WeaponController",
	"AbilityController",
	"UIController",
}

local loaded = {}
for _, name in ORDER do
	loaded[name] = require(Controllers:WaitForChild(name))
end
for _, name in ORDER do
	loaded[name]:Init()
end
for _, name in ORDER do
	loaded[name]:Start()
end
