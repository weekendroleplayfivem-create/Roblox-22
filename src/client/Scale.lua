--!strict
-- Scales fixed-size UI panels down on small screens (phones) and slightly up on big ones.
-- Attach it to panels that are anchored to a screen edge; they shrink around their anchor.

local Scale = {}

local camera = workspace.CurrentCamera
local scales: { UIScale } = {}

local function current(): number
	local vp = camera.ViewportSize
	-- designed at 1280x720
	return math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.55, 1.15)
end

function Scale.Value(): number
	return current()
end

function Scale.Attach(obj: GuiObject, extra: number?)
	local s = Instance.new("UIScale")
	s.Scale = current() * (extra or 1)
	s:SetAttribute("Extra", extra or 1)
	s.Parent = obj
	table.insert(scales, s)
	return s
end

camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	local v = current()
	for _, s in scales do
		local extra = s:GetAttribute("Extra")
		s.Scale = v * (if type(extra) == "number" then extra else 1)
	end
end)

return Scale
