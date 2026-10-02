--[[
	Crosshair
	Dynamic crosshair + hit feedback.
	  * Gap follows the weapon's real spread (movement, jumping, shooting,
	    aiming all change it) so what you see matches where shots go.
	  * Styles: Cross / Dot from Settings; Halo / Chevron from Shop cosmetics.
	  * Colour and size from Settings.
	  * Hit marker: predicted (faint) on your client, confirmed (solid) by
	    the server. Headshots = yellow, eliminations = pink and larger.
	  * Optional floating damage numbers.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local RaycastUtil = require(Shared.Modules.RaycastUtil)
local SettingsConfig = require(Shared.Config.SettingsConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)

local UIKit = require(script.Parent.UIKit)
local ClientState = require(script.Parent.Parent.ClientState)
local SoundController = require(script.Parent.Parent.SoundController)
local WeaponController = require(script.Parent.Parent.WeaponController)
local EffectsController = require(script.Parent.Parent.EffectsController)

local Crosshair = {}

local LINE_LENGTH = 9
local LINE_THICKNESS = 2
local MIN_GAP = 3
local MAX_GAP = 120
local HITMARKER_SIZE = 10

local root: Frame
local lines: { Frame } = {}
local dot: Frame
local circle: Frame
local chevron: { Frame } = {}
local chargeRing: Frame
local hitmarker: Frame
local hitLines: { Frame } = {}
local hitTime = 0
local hitDuration = 0.18
local smoothedGap = 6

local function line(parent: Instance, rotation: number?): Frame
	local frame = UIKit.Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Rotation = rotation or 0,
		Parent = parent,
	})
	UIKit.Create("UIStroke", { Thickness = 1, Transparency = 0.6, Color = Color3.new(0, 0, 0), Parent = frame })
	return frame
end

local function currentStyle(): string
	local profile = ClientState.Get("Profile")
	local item = profile and CosmeticConfig.Get(profile.Equipped.Crosshair)
	if item and item.Price > 0 and item.Style then
		return item.Style
	end
	return ClientState.GetSetting("CrosshairStyle")
end

local function currentColor(): Color3
	return SettingsConfig.CrosshairColors[ClientState.GetSetting("CrosshairColor")] or Color3.new(1, 1, 1)
end

function Crosshair:Build(screen: ScreenGui)
	root = UIKit.Create("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	for _ = 1, 4 do
		table.insert(lines, line(root))
	end
	dot = line(root)
	dot.Size = UDim2.fromOffset(3, 3)
	UIKit.Corner(dot, 2)
	circle = UIKit.Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = root,
	})
	UIKit.Corner(circle, 999)
	UIKit.Create("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Parent = circle })
	chevron = { line(root, 45), line(root, -45) }
	chargeRing = UIKit.Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	})
	UIKit.Corner(chargeRing, 999)
	UIKit.Create("UIStroke", { Name = "Stroke", Thickness = 3, Color = UIKit.Theme.Accent, Parent = chargeRing })

	hitmarker = UIKit.Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		Parent = root,
	})
	for index = 1, 4 do
		local angle = 45 + (index - 1) * 90
		local hitLine = line(hitmarker, angle)
		hitLine.Size = UDim2.fromOffset(HITMARKER_SIZE, LINE_THICKNESS)
		local radians = math.rad(angle)
		hitLine.Position = UDim2.fromOffset(math.cos(radians) * 12, math.sin(radians) * 12)
		hitLine.BackgroundTransparency = 1
		table.insert(hitLines, hitLine)
	end
end

local function showHitmarker(color: Color3, scale: number, opacity: number, duration: number)
	hitTime = os.clock()
	hitDuration = duration
	for index, hitLine in hitLines do
		local angle = math.rad(45 + (index - 1) * 90)
		hitLine.BackgroundColor3 = color
		hitLine.BackgroundTransparency = 1 - opacity
		hitLine.Size = UDim2.fromOffset(HITMARKER_SIZE * scale, LINE_THICKNESS + (scale > 1.2 and 1 or 0))
		hitLine.Position = UDim2.fromOffset(math.cos(angle) * 12 * scale, math.sin(angle) * 12 * scale)
	end
end

local function damageNumber(position: Vector3, amount: number, color: Color3)
	if not ClientState.GetSetting("ShowDamageNumbers") then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.1
	anchor.Position = position + Vector3.new(math.random() - 0.5, 1, math.random() - 0.5)
	anchor.Parent = RaycastUtil.GetContainer(RaycastUtil.Containers.Effects)
	local billboard = UIKit.Create("BillboardGui", {
		Size = UDim2.fromOffset(80, 30),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Parent = anchor,
	})
	local label = UIKit.Label({
		Text = tostring(amount),
		TextColor3 = color,
		Font = UIKit.FontBlack,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		TextStrokeTransparency = 0.4,
		Parent = billboard,
	})
	UIKit.Tween(billboard, 0.6, { StudsOffset = Vector3.new(0, 2, 0) })
	UIKit.Tween(label, 0.6, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(anchor, 0.7)
end

function Crosshair:Update()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local hud = WeaponController:GetHudInfo()
	local inMatch = ClientState.IsInMatch()
	root.Visible = inMatch
	if not inMatch then
		return
	end

	local color = currentColor()
	local sizeScale = ClientState.GetSetting("CrosshairSize")
	local style = currentStyle()
	local aiming = WeaponController:IsAiming()

	-- Convert spread angle to on-screen pixels for an honest crosshair.
	local spread = if hud then WeaponController:GetSpreadDegrees() else 0
	local halfFov = math.rad(camera.FieldOfView / 2)
	local pixels = math.tan(math.rad(spread)) / math.tan(halfFov) * (camera.ViewportSize.Y / 2)
	local targetGap = math.clamp(pixels, MIN_GAP, MAX_GAP)
	smoothedGap += (targetGap - smoothedGap) * 0.35
	local gap = smoothedGap

	local showLines = style == "Cross" and not (aiming and hud and hud.Weapon.Spread.Ads < 0.2)
	local length = LINE_LENGTH * sizeScale
	local thickness = math.max(1, math.floor(LINE_THICKNESS * sizeScale + 0.5))
	local offsets = { Vector2.new(0, -1), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(1, 0) }
	for index, frame in lines do
		local direction = offsets[index]
		frame.Visible = showLines
		frame.BackgroundColor3 = color
		frame.Size = if direction.X == 0 then UDim2.fromOffset(thickness, length) else UDim2.fromOffset(length, thickness)
		frame.Position = UDim2.fromOffset(direction.X * (gap + length / 2), direction.Y * (gap + length / 2))
	end
	dot.Visible = style == "Dot" or style == "Cross" or style == "Circle"
	dot.BackgroundColor3 = color
	dot.Size = UDim2.fromOffset(3 * sizeScale, 3 * sizeScale)

	circle.Visible = style == "Circle"
	circle.Size = UDim2.fromOffset(gap * 2 + 6, gap * 2 + 6)
	local circleStroke = circle:FindFirstChildOfClass("UIStroke")
	if circleStroke then
		circleStroke.Color = color
	end
	for index, frame in chevron do
		frame.Visible = style == "Chevron"
		frame.BackgroundColor3 = color
		frame.Size = UDim2.fromOffset(length, thickness)
		frame.Position = UDim2.fromOffset((index == 1 and -1 or 1) * (length * 0.35), gap + 4)
	end

	local charge = if hud then hud.Charge else 0
	chargeRing.Visible = charge > 0
	if charge > 0 then
		local size = 60 - charge * 34
		chargeRing.Size = UDim2.fromOffset(size, size)
		local stroke = chargeRing:FindFirstChild("Stroke") :: UIStroke
		stroke.Color = UIKit.Theme.Accent:Lerp(Color3.new(1, 1, 1), charge)
		stroke.Transparency = 0.6 - charge * 0.5
	end

	-- Fade hit marker.
	local alpha = (os.clock() - hitTime) / hitDuration
	if alpha >= 1 then
		for _, hitLine in hitLines do
			hitLine.BackgroundTransparency = 1
		end
	end
end

function Crosshair:Start()
	WeaponController.PredictedHit:Connect(function(headshot)
		showHitmarker(if headshot then UIKit.Theme.Yellow else Color3.new(1, 1, 1), 0.9, 0.45, 0.12)
	end)
	Net.Event("Combat", "HitConfirm").OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		if data.Blocked then
			showHitmarker(UIKit.Theme.Locked, 0.8, 0.8, 0.15)
			return
		end
		if data.Decoy then
			showHitmarker(Color3.fromRGB(120, 255, 200), 1, 1, 0.2)
			SoundController:Play("Hit")
			return
		end
		if data.Killed then
			showHitmarker(UIKit.Theme.Accent2, 1.5, 1, 0.4)
			SoundController:Play("Elimination")
		elseif data.Headshot then
			showHitmarker(UIKit.Theme.Yellow, 1.2, 1, 0.22)
			SoundController:Play("Headshot", 0.05)
		else
			showHitmarker(if data.ShieldHit then UIKit.Theme.Accent else Color3.new(1, 1, 1), 1, 1, 0.18)
			SoundController:Play("Hit", 0.08)
		end
		if data.ShieldBroken then
			SoundController:Play("ShieldBreak")
			if typeof(data.Position) == "Vector3" then
				EffectsController:ShieldShatter(data.Position)
			end
		end
		if typeof(data.Position) == "Vector3" and data.Damage then
			local color = if data.Headshot then UIKit.Theme.Yellow elseif data.ShieldHit then UIKit.Theme.Accent else Color3.new(1, 1, 1)
			damageNumber(data.Position, data.Damage, color)
		end
	end)
end

return Crosshair
