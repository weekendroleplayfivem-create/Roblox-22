--[[
	ScooterBuilder
	Procedurally assembles a combat-scooter model from parts (see brief
	section 42: prefer generated geometry over hand placement). Used by the
	server to spawn a rideable scooter and by the client to render cosmetic
	previews in the Inventory/Loadout UI.
]]

local ScooterData = require(script.Parent.ScooterData)

local ScooterBuilder = {}

local function neonPart(size, cframe, color)
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Anchored = false
	part.CanCollide = false
	part.CastShadow = false
	return part
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
	deck.CanCollide = true
	deck.CFrame = CFrame.new(0, 1.5, 0)
	deck.Parent = model
	model.PrimaryPart = deck

	local stripe = neonPart(Vector3.new(0.2, 0.06, 4.6), deck.CFrame * CFrame.new(0, 0.21, 0), skin.AccentColor)
	stripe.Parent = model
	local weldStripe = Instance.new("WeldConstraint")
	weldStripe.Part0 = deck
	weldStripe.Part1 = stripe
	weldStripe.Parent = stripe

	local stem = Instance.new("Part")
	stem.Name = "Stem"
	stem.Size = Vector3.new(0.3, 3, 0.3)
	stem.Material = skin.Material
	stem.Color = skin.BodyColor
	stem.CanCollide = false
	stem.CFrame = deck.CFrame * CFrame.new(0, 1.5, -2.2)
	stem.Parent = model
	local weldStem = Instance.new("WeldConstraint")
	weldStem.Part0 = deck
	weldStem.Part1 = stem
	weldStem.Parent = stem

	local handlebar = Instance.new("Part")
	handlebar.Name = "Handlebar"
	handlebar.Size = Vector3.new(2, 0.25, 0.25)
	handlebar.Material = skin.Material
	handlebar.Color = skin.AccentColor
	handlebar.CanCollide = false
	handlebar.CFrame = stem.CFrame * CFrame.new(0, 1.5, 0)
	handlebar.Parent = model
	local weldBar = Instance.new("WeldConstraint")
	weldBar.Part0 = deck
	weldBar.Part1 = handlebar
	weldBar.Parent = handlebar

	for _, offsetZ in ipairs({ 2.1, -2.1 }) do
		local wheel = Instance.new("Part")
		wheel.Name = "Wheel"
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Size = Vector3.new(0.4, 1.1, 1.1)
		wheel.Material = Enum.Material.Metal
		wheel.Color = Color3.fromRGB(20, 20, 20)
		wheel.CanCollide = false
		wheel.CFrame = deck.CFrame * CFrame.new(0, -0.6, offsetZ) * CFrame.Angles(0, 0, math.rad(90))
		wheel.Parent = model
		local weldWheel = Instance.new("WeldConstraint")
		weldWheel.Part0 = deck
		weldWheel.Part1 = wheel
		weldWheel.Parent = wheel

		local wheelGlow = neonPart(Vector3.new(0.42, 0.5, 0.5), wheel.CFrame, skin.AccentColor)
		wheelGlow.Shape = Enum.PartType.Cylinder
		wheelGlow.Transparency = 0.35
		wheelGlow.Parent = model
		local weldGlow = Instance.new("WeldConstraint")
		weldGlow.Part0 = deck
		weldGlow.Part1 = wheelGlow
		weldGlow.Parent = wheelGlow
	end

	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(1.8, 0.3, 1.6)
	seat.Transparency = 1
	seat.MaxSpeed = 0 -- we drive velocity ourselves; disable built-in car physics
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.CFrame = deck.CFrame * CFrame.new(0, 0.35, 0.6)
	seat.Parent = model
	local weldSeat = Instance.new("WeldConstraint")
	weldSeat.Part0 = deck
	weldSeat.Part1 = seat
	weldSeat.Parent = seat

	local light = Instance.new("PointLight")
	light.Color = skin.AccentColor
	light.Range = 12
	light.Brightness = 2
	light.Parent = stripe

	local trailAttachment0 = Instance.new("Attachment")
	trailAttachment0.Name = "TrailAttachment0"
	trailAttachment0.Position = Vector3.new(-1, -0.4, -2.4)
	trailAttachment0.Parent = deck

	local trailAttachment1 = Instance.new("Attachment")
	trailAttachment1.Name = "TrailAttachment1"
	trailAttachment1.Position = Vector3.new(1, -0.4, -2.4)
	trailAttachment1.Parent = deck

	local trail = Instance.new("Trail")
	trail.Attachment0 = trailAttachment0
	trail.Attachment1 = trailAttachment1
	trail.Color = ColorSequence.new(skin.AccentColor)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.4
	trail.Enabled = false
	trail.Name = "BoostTrail"
	trail.Parent = deck

	model:SetAttribute("SkinId", skin.Id)
	return model
end

return ScooterBuilder
