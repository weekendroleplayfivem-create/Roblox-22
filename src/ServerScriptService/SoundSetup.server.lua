--[[
	SoundSetup
	Creates the SoundGroups the whole game routes audio through (brief
	section 34) plus clearly-named placeholder Sound objects for anything
	that doesn't have a final audio asset yet. Settings UI controls these
	group volumes directly.
]]

local SoundService = game:GetService("SoundService")

local GROUP_NAMES = { "Music", "SFX", "Weapons", "UI", "Vehicles", "Environment" }

for _, name in ipairs(GROUP_NAMES) do
	if not SoundService:FindFirstChild(name) then
		local group = Instance.new("SoundGroup")
		group.Name = name
		group.Parent = SoundService
	end
end

local function placeholder(name, groupName, looped, volume)
	local group = SoundService:FindFirstChild(groupName)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundGroup = group
	sound.Looped = looped or false
	sound.Volume = volume or 0.5
	-- SoundId intentionally left blank: drop a real asset id in Studio when
	-- final audio is ready. Name alone documents what belongs here.
	sound.Parent = group
	return sound
end

placeholder("MenuMusic", "Music", true, 0.4)
placeholder("MatchMusic", "Music", true, 0.35)
placeholder("ScooterEngineLoop", "Vehicles", true, 0.3)
placeholder("BoostLoop", "Vehicles", true, 0.4)
placeholder("DriftLoop", "Vehicles", true, 0.35)
placeholder("JumpLand", "Vehicles", false, 0.5)
placeholder("WeaponReload", "Weapons", false, 0.5)
placeholder("EliminationStinger", "SFX", false, 0.6)
placeholder("VictoryStinger", "SFX", false, 0.7)
placeholder("DefeatStinger", "SFX", false, 0.7)
placeholder("UIClick", "UI", false, 0.5)
placeholder("UIHover", "UI", false, 0.3)
placeholder("AmbientCity", "Environment", true, 0.25)

print("[HyperBlast] Sound groups initialized")
