--!nonstrict
--[[
	InputController.luau
	One place that turns hardware into *actions*, so no gameplay controller ever
	names a KeyCode. Keyboard/mouse and gamepad map onto the same action set, which
	is what makes the two input methods feel identical rather than "ported".

	It also owns input BUFFERING. In a movement game the difference between "the
	combo felt tight" and "the game ate my input" is a ~140ms buffer on the actions
	that gate a combo (jump, slide, dash). Buffers are fixed-length and never
	adaptive - a predictable buffer is learnable.
--]]

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local Signal = require(Root.Util.Signal)
local Trove = require(Root.Util.Trove)
local MovementConfig = require(Root.Config.MovementConfig)

local InputController = {}
InputController.__index = InputController

-- Action -> inputs. Multiple bindings per action are supported and expected.
local BINDINGS = {
	Jump = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA },
	Sprint = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 },
	Crouch = { Enum.KeyCode.LeftControl, Enum.KeyCode.C, Enum.KeyCode.ButtonL3 },
	Slide = { Enum.KeyCode.LeftControl, Enum.KeyCode.C, Enum.KeyCode.ButtonB },

	Fire = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 },
	Aim = { Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2 },
	Reload = { Enum.KeyCode.R, Enum.KeyCode.ButtonX },
	Inspect = { Enum.KeyCode.T, Enum.KeyCode.DPadUp },
	Melee = { Enum.KeyCode.V, Enum.KeyCode.ButtonR3 },

	Slot1 = { Enum.KeyCode.One },
	Slot2 = { Enum.KeyCode.Two },
	Slot3 = { Enum.KeyCode.Three },
	NextWeapon = { Enum.KeyCode.DPadRight },

	Ability1 = { Enum.KeyCode.Q, Enum.KeyCode.ButtonL1 }, -- Hyper Dash
	Ability2 = { Enum.KeyCode.E, Enum.KeyCode.ButtonR1 }, -- Phase Step
	Ability3 = { Enum.KeyCode.F, Enum.KeyCode.ButtonY }, -- Overdrive

	Scoreboard = { Enum.KeyCode.Tab, Enum.KeyCode.ButtonSelect },
	Ping = { Enum.KeyCode.G, Enum.KeyCode.DPadLeft },
}

-- Actions that get an input buffer, and how long it lives.
local BUFFERED = {
	Jump = MovementConfig.Buffer.Jump,
	Slide = MovementConfig.Buffer.Slide,
	Ability1 = MovementConfig.Buffer.Dash,
	Fire = 0.10, -- so a click during a reload/swap fires the instant it ends
}

function InputController.new()
	local self = setmetatable({}, InputController)

	self._trove = Trove.new()
	self._down = {} :: { [string]: boolean }
	self._buffers = {} :: { [string]: number }
	self._lookup = {} :: { [any]: { string } }
	self._enabled = true

	self.ActionPressed = Signal.new()
	self.ActionReleased = Signal.new()
	self.GamepadActive = false

	for action, inputs in BINDINGS do
		for _, input in inputs do
			local list = self._lookup[input]
			if not list then
				list = {}
				self._lookup[input] = list
			end
			table.insert(list, action)
		end
	end

	return self
end

function InputController:_resolve(input: InputObject): { string }?
	if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.Gamepad1 then
		return self._lookup[input.KeyCode]
	end
	return self._lookup[input.UserInputType]
end

function InputController:Start()
	self._trove:Add(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not self._enabled then
			return
		end
		local actions = self:_resolve(input)
		if not actions then
			return
		end
		if input.UserInputType == Enum.UserInputType.Gamepad1 then
			self.GamepadActive = true
		end
		for _, action in actions do
			self._down[action] = true
			local bufferTime = BUFFERED[action]
			if bufferTime then
				self._buffers[action] = os.clock() + bufferTime
			end
			self.ActionPressed:FireSync(action)
		end
	end))

	self._trove:Add(UserInputService.InputEnded:Connect(function(input)
		local actions = self:_resolve(input)
		if not actions then
			return
		end
		for _, action in actions do
			if self._down[action] then
				self._down[action] = false
				self.ActionReleased:FireSync(action)
			end
		end
	end))

	self:_bindSinkedActions()

	-- Losing window focus must release everything, or the player comes back
	-- from alt-tab still sprinting into a wall.
	self._trove:Add(UserInputService.WindowFocusReleased:Connect(function()
		self:ReleaseAll()
	end))

	return self
end

--[[ Jump is owned by Roblox's default control module, which would fire the
	 Humanoid's jump the instant Space goes down - stealing coyote time and jump
	 buffering from us. We bind it at a higher ContextActionService priority and
	 SINK it, then re-emit it as a normal action. Everything else can ride on
	 UserInputService, because nothing else is contested. ]]
function InputController:_bindSinkedActions()
	local ACTION_NAME = "HyperBlast_Jump"

	ContextActionService:BindActionAtPriority(ACTION_NAME, function(_, inputState)
		if not self._enabled then
			return Enum.ContextActionResult.Sink
		end

		if inputState == Enum.UserInputState.Begin then
			self._down.Jump = true
			self._buffers.Jump = os.clock() + BUFFERED.Jump
			self.ActionPressed:FireSync("Jump")
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			if self._down.Jump then
				self._down.Jump = false
				self.ActionReleased:FireSync("Jump")
			end
		end

		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

	self._trove:Fn(function()
		ContextActionService:UnbindAction(ACTION_NAME)
	end)
end

function InputController:IsDown(action: string): boolean
	return self._enabled and self._down[action] == true
end

--[[ True if the action was pressed inside its buffer window. Consuming clears it,
	 which is what stops one press from firing two combo steps. ]]
function InputController:ConsumeBuffer(action: string): boolean
	local expiry = self._buffers[action]
	if expiry and os.clock() <= expiry then
		self._buffers[action] = nil
		return true
	end
	return false
end

function InputController:PeekBuffer(action: string): boolean
	local expiry = self._buffers[action]
	return expiry ~= nil and os.clock() <= expiry
end

function InputController:ClearBuffer(action: string)
	self._buffers[action] = nil
end

function InputController:ReleaseAll()
	for action, isDown in self._down do
		if isDown then
			self._down[action] = false
			self.ActionReleased:FireSync(action)
		end
	end
	table.clear(self._buffers)
end

--[[ Disabled during warmup / post-match so players can't shoot the intro. ]]
function InputController:SetEnabled(enabled: boolean)
	if self._enabled == enabled then
		return
	end
	self._enabled = enabled
	if not enabled then
		self:ReleaseAll()
	end
end

function InputController:GetBindings()
	return BINDINGS
end

function InputController:Destroy()
	self._trove:Clean()
end

return InputController
