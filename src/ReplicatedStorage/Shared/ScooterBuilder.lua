--[[
	ScooterBuilder
	Procedurally assembles a combat-scooter model from parts (see brief
	section 42: prefer generated geometry over hand placement).

	The scooter is a *welded cosmetic rig*, not a seated physics vehicle: every
	part is massless and non-colliding, and the whole model is welded under the
	player's HumanoidRootPart. Movement feel (accel/boost/drift) is applied to
	the Humanoid itself by ScooterController. That keeps driving on top of
	Roblox's own character controller, which is far more reliable than a
	VehicleSeat + BodyVelocity chain, and means the player can always move.
]]

local ScooterData = require(script.Parent.ScooterData)

local ScooterBuilder = {}

-- Where the deck sits relative to the character's HumanoidRootPart.
ScooterBuilder.RideOffset = CFrame.new(0, -2.6, 0)

-- Every scooter part: no collision, no mass, so it never fights the character
-- it's welded to and never traps the player inside geometry.
local function configure(part)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = true
	part.Massless = true
	part.CastShadow = false
	return part
end

local function weldTo(root, part)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return weld
end

function ScooterBuilder.Build(skinId)
	local skin = ScooterData.Skins[skinId] or ScooterData.Skins[ScooterData.DefaultSkin]

	local model = Instance.new("Model")
	model.Name = "Scooter"

	local deck = Instance.new("Part")
	deck.Name = "Deck"
	deck.Size = Vector3.new(2.2, 0.35, 5)
	deck.Material = skin.Material
	deck.Color = skin.BodyColor
	deck.CFrame = CFrame.new(0, 1.5, 0)
	configure(deck)
	deck.Parent = model
	model.PrimaryPart = deck

	local function addPart(name, size, cframe, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Material = material or skin.Material
		configure(p)
		p.Parent = model
		weldTo(deck, p)
		return p
	end

	addPart("Stripe", Vector3.new(0.2, 0.06, 4.6), deck.CFrame * CFrame.new(0, 0.21, 0), skin.AccentColor, Enum.Material.Neon)

	local stem = addPart("Stem", Vector3.new(0.3, 2.4, 0.3), deck.CFrame * CFrame.new(0, 1.2, -2.2), skin.BodyColor)
	addPart("Handlebar", Vector3.new(2, 0.25, 0.25), stem.CFrame * CFrame.new(0, 1.2, 0), skin.AccentColor)

	for index, offsetZ in ipairs({ 2.1, -2.1 }) do
		local wheel = addPart(
			"Wheel" .. index,
			Vector3.new(0.4, 1.1, 1.1),
			deck.CFrame * CFrame.new(0, -0.6, offsetZ) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(20, 20, 20),
			Enum.Material.Metal
		)
		wheel.Shape = Enum.PartType.Cylinder

		local glow = addPart(
			"WheelGlow" .. index,
			Vector3.new(0.42, 0.5, 0.5),
			wheel.CFrame,
			skin.AccentColor,
			Enum.Material.Neon
		)
		glow.Shape = Enum.PartType.Cylinder
		glow.Transparency = 0.35
	end

	local light = Instance.new("PointLight")
	light.Color = skin.AccentColor
	light.Range = 14
	light.Brightness = 2
	light.Parent = deck

	local trailAttachment0 = Instance.new("Attachment")
	trailAttachment0.Name = "TrailAttachment0"
	trailAttachment0.Position = Vector3.new(-1, -0.4, 2.4)
	trailAttachment0.Parent = deck

	local trailAttachment1 = Instance.new("Attachment")
	trailAttachment1.Name = "TrailAttachment1"
	trailAttachment1.Position = Vector3.new(1, -0.4, 2.4)
	trailAttachment1.Parent = deck

	local trail = Instance.new("Trail")
	trail.Name = "BoostTrail"
	trail.Attachment0 = trailAttachment0
	trail.Attachment1 = trailAttachment1
	trail.Color = ColorSequence.new(skin.AccentColor)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.45
	trail.Enabled = false
	trail.Parent = deck

	model:SetAttribute("SkinId", skin.Id)
	return model
end

-- Welds a freshly built scooter under a character. Returns the Weld so the
-- client can animate C0 for cosmetic lean while turning.
function ScooterBuilder.AttachTo(model, character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local deck = model.PrimaryPart
	if not root or not deck then
		return nil
	end

	-- Sit the deck just below the character's feet.
	model:PivotTo(root.CFrame * ScooterBuilder.RideOffset)

	local weld = Instance.new("Weld")
	weld.Name = "ScooterWeld"
	weld.Part0 = root
	weld.Part1 = deck
	weld.C0 = ScooterBuilder.RideOffset
	weld.Parent = deck

	return weld
end

return ScooterBuilder
