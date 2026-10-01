--[[
	AbilityConfig
	Players equip one "Movement" ability and one "Tactical" ability.
	Cooldowns are enforced by the server (AbilityService); the client only
	predicts them for UI.
]]

local TableUtil = require(script.Parent.Parent.Modules.TableUtil)

local Abilities = {
	Dash = {
		DisplayName = "Dash",
		Slot = "Movement",
		Description = "Burst quickly in the direction you're moving.",
		Cooldown = 4,
		-- Movement numbers live in PlayerConfig.Movement.Dash.
		UnlockLevel = 1,
		Color = Color3.fromRGB(60, 230, 255),
		Sound = "Dash",
	},
	Phase = {
		DisplayName = "Phase",
		Slot = "Movement",
		Description = "Shift partly out of sight and move faster for a moment.",
		Cooldown = 11,
		Duration = 2.5,
		SpeedMultiplier = 1.3,
		-- How see-through the phased player looks to others (0..1).
		Transparency = 0.65,
		UnlockLevel = 4,
		Color = Color3.fromRGB(180, 120, 255),
		Sound = "Phase",
	},
	Shield = {
		DisplayName = "Barrier",
		Slot = "Tactical",
		Description = "Deploy an energy wall that blocks enemy shots.",
		Cooldown = 18,
		Duration = 5,
		Size = Vector3.new(10, 8, 0.6),
		Distance = 6, -- studs in front of the player
		UnlockLevel = 1,
		Color = Color3.fromRGB(80, 200, 255),
		Sound = "Shield",
	},
	Decoy = {
		DisplayName = "Decoy",
		Slot = "Tactical",
		Description = "Send out a hologram that runs forward and draws fire.",
		Cooldown = 15,
		Duration = 5,
		RunSpeed = 22,
		UnlockLevel = 3,
		Color = Color3.fromRGB(120, 255, 200),
		Sound = "Decoy",
	},
	Pulse = {
		DisplayName = "Scan Pulse",
		Slot = "Tactical",
		Description = "Briefly reveal nearby opponents to your team.",
		Cooldown = 20,
		Radius = 70,
		RevealDuration = 2.5,
		UnlockLevel = 2,
		Color = Color3.fromRGB(255, 220, 80),
		Sound = "Pulse",
	},
	Gravity = {
		DisplayName = "Low-G Field",
		Slot = "Tactical",
		Description = "Create a bubble of low gravity for big jumps.",
		Cooldown = 20,
		Duration = 6,
		Radius = 16,
		GravityMultiplier = 0.35,
		Range = 40, -- max placement distance
		UnlockLevel = 6,
		Color = Color3.fromRGB(255, 120, 220),
		Sound = "Gravity",
	},
}

for id, ability in Abilities do
	ability.Id = id
end

local AbilityConfig = {
	Abilities = Abilities,
	Order = { "Dash", "Phase", "Shield", "Pulse", "Decoy", "Gravity" },
	DefaultMovement = "Dash",
	DefaultTactical = "Shield",
	-- Client/server clock slack allowed when checking cooldowns (seconds).
	CooldownTolerance = 0.15,
}

function AbilityConfig.Get(id: string)
	return Abilities[id]
end

return TableUtil.DeepFreeze(AbilityConfig)
