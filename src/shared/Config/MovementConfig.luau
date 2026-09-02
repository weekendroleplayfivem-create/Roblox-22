--!nonstrict
--[[
	MovementConfig.luau
	Every tunable number for the HYPER BLAST movement model lives here.

	Design pillars (do not tune away):
		1. RESPONSIVE  - input-to-motion latency is one frame. No input buffering
		                 longer than `Buffer.Jump`, no animation locks on movement.
		2. READABLE    - the camera never shakes hard enough to break aim. Feedback
		                 is communicated with FOV, roll, trails and audio instead.
		3. SKILL FLOOR - walking + jumping alone is comfortable and viable.
		4. SKILL CEILING - chaining sprint -> slide -> jump -> air dash -> wall jump
		                 preserves (and briefly compounds) momentum, so the good
		                 player crosses the map faster than the good player's aim
		                 can be punished for it.

	Units: studs, seconds, studs/second, degrees.
	Workspace.Gravity is 145 (see default.project.json) - lower than Roblox default
	so airtime is long enough to steer, without feeling floaty.
--]]

local MovementConfig = {}

----------------------------------------------------------------------
-- Ground locomotion
----------------------------------------------------------------------
MovementConfig.Speed = {
	Walk = 20, -- default, weapon-agnostic base speed
	Sprint = 30, -- costs stamina, forward-biased
	Crouch = 11, -- crouch-walk
	Backpedal = 0.82, -- multiplier when moving away from aim direction
	Strafe = 0.94, -- multiplier when moving perpendicular to aim
	AdsMultiplier = 0.55, -- while aiming down sights
	MaxMomentum = 62, -- absolute horizontal speed cap (anti-cheat mirrors this)
}

MovementConfig.Acceleration = {
	Ground = 145, -- studs/s^2 toward target speed on the floor
	GroundBrake = 115, -- studs/s^2 when input released / over-speed on the floor
	MomentumBleed = 26, -- studs/s^2 that excess (post-slide/dash) speed decays at
	CrouchBrake = 160,
}

----------------------------------------------------------------------
-- Jumping & air control
----------------------------------------------------------------------
MovementConfig.Jump = {
	Height = 7.6, -- studs of apex above the feet
	CoyoteTime = 0.12, -- can still jump this long after leaving a ledge
	BufferTime = 0.14, -- jump pressed this long before landing still fires
	HopWindow = 0.18, -- land + rejump inside this window keeps full momentum
	HopSpeedKeep = 1.0, -- fraction of horizontal speed kept on a clean hop
	LandSpeedKeep = 0.9, -- fraction kept on a normal (non-hop) landing
	MinCrouchLandBoost = 0.06, -- crouch on landing to cancel a little friction
}

-- Quake-style air acceleration. The magic of this model: `WishSpeed` is small,
-- so moving the stick sideways while turning the camera adds speed instead of
-- capping it. That is the entire strafe-jumping skill ceiling in four numbers.
MovementConfig.Air = {
	Accel = 105, -- studs/s^2 applied along the wish direction
	WishSpeed = 9.5, -- projected speed cap per-axis for the accel formula
	SpeedCap = 48, -- soft cap on horizontal air speed from strafing alone
	Drag = 3.0, -- 1/s exponential decay applied to speed *above* SpeedCap
	Control = 0.65, -- 0..1 authority multiplier (1 = full ground-like control)
	FastFallMultiplier = 1.18, -- extra gravity past apex, keeps jumps snappy
}

----------------------------------------------------------------------
-- Sprint & stamina
----------------------------------------------------------------------
MovementConfig.Stamina = {
	Max = 100,
	SprintDrain = 13, -- per second while sprinting
	SlideCost = 14, -- one-off on slide entry
	WallJumpCost = 9, -- one-off per wall jump
	MantleCost = 6,
	Regen = 21, -- per second once regen starts
	RegenDelay = 0.75, -- after the last drain
	ExhaustedRegenDelay = 1.6, -- longer punish if you hit zero
	SprintMinimum = 12, -- can't *start* a sprint below this
	SprintDotThreshold = 0.35, -- must be moving roughly where you're looking
}

----------------------------------------------------------------------
-- Slide
----------------------------------------------------------------------
MovementConfig.Slide = {
	EntrySpeedRequired = 22, -- must be at least this fast to slide instead of crouch
	EntryBoost = 1.34, -- multiplier applied to current speed on entry
	EntryMinSpeed = 34, -- floor for the post-boost speed (slides always feel fast)
	EntryMaxSpeed = 52, -- ceiling so dash->slide can't spiral
	Friction = 15, -- studs/s^2 bled on flat ground
	SlopeAccel = 62, -- studs/s^2 gained per unit of downhill slope
	SlopeBrake = 44, -- studs/s^2 lost going uphill
	MinSpeed = 17, -- below this the slide ends
	MinDuration = 0.22, -- can't instantly cancel (prevents slide-spam jitter)
	MaxDuration = 1.35,
	SteerRate = 3.6, -- radians/s the slide direction can be curved
	Cooldown = 0.28,
	HeightOffset = 2.1, -- how far the camera/hitbox drops
	JumpSpeedKeep = 1.0, -- slide-hop keeps all of it (the core combo)
	CameraRoll = 5.5, -- degrees of roll into the slide
	CameraDip = 0.55, -- studs the camera dips on entry (spring, not a snap)
}

----------------------------------------------------------------------
-- Crouch
----------------------------------------------------------------------
MovementConfig.Crouch = {
	HeightOffset = 1.7,
	TransitionSpeed = 12, -- studs/s the camera moves between stances
	UncrouchClearance = 4.2, -- headroom needed to stand back up
}

----------------------------------------------------------------------
-- Wall interaction (wall jump + wall slide)
----------------------------------------------------------------------
MovementConfig.Wall = {
	DetectDistance = 2.6, -- ray length from the root to a wall
	MinHeightAboveGround = 2.0, -- can't wall jump off the floor you're standing on
	MaxNormalY = 0.35, -- surfaces steeper than this are "walls"
	JumpOutSpeed = 30, -- push away from the wall
	JumpUpSpeed = 34, -- vertical kick (tuned against Gravity = 145)
	ForwardKeep = 0.55, -- fraction of pre-jump forward speed carried through
	MaxChain = 3, -- consecutive wall jumps before touching ground again
	SameWallLockout = 0.45, -- can't re-use the *same* wall inside this window
	SlideGravityScale = 0.45, -- gravity while hugging a wall and falling
	SlideMaxFallSpeed = 22,
	Cooldown = 0.16,
	-- Surfaces must be tagged (see Tags.WallJump) OR flagged with the
	-- `HyperBlast_WallJump` attribute. Arena design decides where the routes are;
	-- players should be able to *see* a wall-jump panel from across the map.
	RequireTaggedSurface = true,
}

----------------------------------------------------------------------
-- Mantle / vault
----------------------------------------------------------------------
MovementConfig.Mantle = {
	MinLedgeHeight = 1.6,
	MaxLedgeHeight = 6.2,
	ForwardCheck = 2.9, -- how far ahead we probe for a wall face
	DepthCheck = 1.6, -- how deep the top surface has to be to stand on
	ClearanceHeight = 4.6, -- headroom needed above the ledge
	Duration = 0.26, -- fast: a mantle must never feel like a cutscene
	ExitSpeed = 16, -- speed granted going over the top
	Cooldown = 0.3,
	MaxDownAngle = 0.7, -- ledge top must be reasonably flat
}

----------------------------------------------------------------------
-- Jump pads (arena furniture, tagged by the arena builder)
----------------------------------------------------------------------
MovementConfig.JumpPad = {
	DefaultPower = 82,
	DefaultForwardKeep = 0.85,
	Cooldown = 0.35,
}

----------------------------------------------------------------------
-- Input buffering. Small, fixed, never adaptive: a predictable buffer is
-- what makes a combo feel "tight" rather than "lucky".
----------------------------------------------------------------------
MovementConfig.Buffer = {
	Jump = 0.14,
	Slide = 0.16,
	Dash = 0.18,
	Mantle = 0.20,
}

----------------------------------------------------------------------
-- Camera reaction to movement. Deliberately restrained - see pillar 2.
----------------------------------------------------------------------
MovementConfig.Camera = {
	BaseFov = 90,
	SprintFovAdd = 6,
	SlideFovAdd = 9,
	DashFovAdd = 13,
	SpeedFovScale = 0.22, -- extra FOV per stud/s above sprint speed
	MaxFovAdd = 20,
	FovSpring = { frequency = 3.2, damping = 0.85 },
	StrafeRoll = 1.9, -- degrees of lean while strafing
	AirRoll = 1.2,
	RollSpring = { frequency = 4.0, damping = 0.9 },
	BobFrequency = 8.6, -- steps/s at sprint speed
	BobAmplitude = 0.075, -- studs - this is view *bob*, not a screen shake
	LandDip = { light = 0.25, heavy = 0.65 }, -- studs, spring-recovered
	LandDipHeavyFallSpeed = 55,
	MaxShake = 0.35, -- hard cap on any positional shake, in studs
}

----------------------------------------------------------------------
-- Networking / replication of movement state
----------------------------------------------------------------------
MovementConfig.Network = {
	SnapshotRate = 12, -- snapshots/sec sent to the server
	StateEventCoalesce = 0.05,
}

----------------------------------------------------------------------
-- Server-side validation. The client owns its character (Roblox physics
-- ownership), so the server audits rather than simulates.
----------------------------------------------------------------------
MovementConfig.Validation = {
	SpeedTolerance = 1.35, -- multiplier over MaxMomentum before we care
	GraceViolations = 4, -- consecutive bad samples before correcting
	CorrectionCooldown = 1.0,
	MaxTeleportDistance = 90, -- studs between samples before it's a teleport
	SampleInterval = 0.25,
}

return MovementConfig
