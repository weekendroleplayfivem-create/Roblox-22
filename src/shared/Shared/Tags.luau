--!nonstrict
--[[
	Tags.luau
	CollectionService tag names shared by the arena builder and the gameplay systems.

	Anything the movement system can interact with is TAGGED, never name-matched.
	That means a level designer can drop a part into the arena, tag it, and the
	movement code picks it up with no script changes.
--]]

return {
	-- Movement surfaces / furniture
	WallJump = "HB_WallJump", -- wall-jumpable panel
	NoMantle = "HB_NoMantle", -- ledge the mantle system must ignore
	JumpPad = "HB_JumpPad", -- launches the player (attributes: Power, ForwardKeep)
	SlideBoost = "HB_SlideBoost", -- low-friction slide tunnel floor
	KillPlane = "HB_KillPlane", -- out-of-bounds volume
	NoShoot = "HB_NoShoot", -- geometry bullets ignore (decorative neon)

	-- Objectives
	ControlZone = "HB_ControlZone",
	CoreSpawn = "HB_CoreSpawn",
	CoreObjective = "HB_CoreObjective",
	TeamSpawn = "HB_TeamSpawn",

	-- Presentation
	NeonAccent = "HB_NeonAccent", -- pulses with the match state
	MinimapGeometry = "HB_MinimapGeometry", -- drawn on the minimap
}
