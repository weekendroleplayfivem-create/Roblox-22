--!nonstrict
--[[
	MovementGuard.luau
	Audits client-simulated movement.

	The client owns its character's physics (that is how Roblox works, and it is
	what makes the movement feel instant), so the server's job is not to simulate
	movement but to notice when the reported movement is impossible.

	Philosophy - and this matters more than the checks themselves:
		* This is an AUDIT, not an anti-cheat arms race. It catches the trivial
		  "set my WalkSpeed to 400" case and nothing more sophisticated, which is
		  the honest limit of what a client-authoritative model can promise.
		* False positives are worse than false negatives. A legitimate player who
		  gets rubber-banded once has a worse match than a lobby with one speed
		  hacker in it. Hence the grace counter and the generous tolerances.
		* Every ceiling comes from MovementState.speedCeiling(), which reads the
		  same MovementConfig the client simulates from. One source of truth: a
		  buff to sliding cannot accidentally make sliding a bannable offence.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local MovementConfig = require(Root.Config.MovementConfig)
local MovementState = require(Root.Shared.MovementState)
local Net = require(Root.Util.Net)

local MovementGuard = {}
MovementGuard.__index = MovementGuard

function MovementGuard.new(services)
	local self = setmetatable({}, MovementGuard)

	self.services = services
	self.samples = {} :: { [Player]: any }
	self._eventLimiter = Net.RateLimiter.new(30, 1)

	return self
end

function MovementGuard:Start()
	Net.onServer("MovementSnapshot", function(player, stateId, position, horizontalSpeed, grounded)
		self:_onSnapshot(player, stateId, position, horizontalSpeed, grounded)
	end)

	-- Discrete movement events are only ever used for cosmetic replication, so
	-- they are rate limited and otherwise trusted; a faked wall jump effect costs
	-- nothing but a particle.
	Net.onServer("MovementEvent", function(player, kind, payload)
		if not self._eventLimiter:Check(player) or type(kind) ~= "string" then
			return
		end
		if kind == "WallJump" or kind == "JumpPad" or kind == "Dash" then
			Net.toOtherClients("EffectBroadcast", player, kind, payload)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.samples[player] = nil
		self._eventLimiter:Clear(player)
	end)

	self.services.Player.CharacterSpawned:Connect(function(player)
		self.samples[player] = nil
	end)

	return self
end

function MovementGuard:_onSnapshot(player: Player, stateId, position, horizontalSpeed, grounded)
	if typeof(position) ~= "Vector3" or type(horizontalSpeed) ~= "number" then
		return
	end
	if not self.services.Player:IsAlive(player) then
		return
	end
	if horizontalSpeed ~= horizontalSpeed then
		return -- NaN
	end

	local stateName = MovementState.Order[stateId] or MovementState.Idle
	local now = os.clock()

	local record = self.samples[player]
	if not record then
		self.samples[player] = {
			position = position,
			at = now,
			violations = 0,
			lastCorrection = 0,
		}
		return
	end

	local elapsed = now - record.at
	if elapsed < MovementConfig.Validation.SampleInterval then
		return
	end

	local travelled = (position - record.position).Magnitude
	local implied = travelled / math.max(elapsed, 1e-3)

	local ceiling = MovementState.speedCeiling(stateName, MovementConfig)
		* self.services.Ability:GetSpeedMultiplier(player)
		* MovementConfig.Validation.SpeedTolerance

	local bad = false

	-- Phase Step legitimately covers ground instantly, so a blink-sized jump is
	-- only suspicious if the player is not entitled to one.
	if travelled > MovementConfig.Validation.MaxTeleportDistance then
		bad = true
	elseif implied > ceiling and stateName ~= MovementState.Phase then
		bad = true
	end

	if bad then
		record.violations += 1
		if
			record.violations >= MovementConfig.Validation.GraceViolations
			and now - record.lastCorrection >= MovementConfig.Validation.CorrectionCooldown
		then
			record.violations = 0
			record.lastCorrection = now
			self:_correct(player, record.position)
		end
	else
		-- Decay rather than reset: an intermittent offender still accumulates.
		record.violations = math.max(0, record.violations - 1)
	end

	record.position = position
	record.at = now
	record.grounded = grounded
end

function MovementGuard:_correct(player: Player, position: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	root.CFrame = CFrame.new(position) * (root.CFrame - root.CFrame.Position)
	root.AssemblyLinearVelocity = Vector3.zero
	Net.toClient("MovementCorrection", player, position)
end

return MovementGuard
