--!strict
-- Black Market window (buy / mount roof weapons) and the fire button (F / gamepad RB / touch).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shop = Remotes:WaitForChild("Shop") :: RemoteFunction
local FireWeapon = Remotes:WaitForChild("FireWeapon") :: RemoteEvent

local HUD = require(script.Parent.HUD)
local Sounds = require(script.Parent.Sounds)
local Drive = require(script.Parent.DriveController)
local Input = require(script.Parent.Input)
local Scale = require(script.Parent.Scale)
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer
local BlackMarket = {}
BlackMarket.Open = false

local RED = Color3.fromRGB(255, 50, 60)

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	if props.Font ~= nil then
		(inst :: any).FontFace = Theme.FontFor(props.Font)
	end
	for k, v in props do
		if k ~= "Font" and k ~= "FontFace" then
			(inst :: any)[k] = v
		end
	end
	if props.FontFace ~= nil then
		(inst :: any).FontFace = props.FontFace
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local base: { [string]: any } = { BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left }
	for k, v in props do
		base[k] = v
	end
	if base.Font == nil and base.FontFace == nil then
		base.FontFace = Theme.Fonts.Body
	end
	return new("TextLabel", base, parent)
end

local window = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(620, 520),
	BackgroundColor3 = Color3.fromRGB(14, 8, 10),
	BackgroundTransparency = 0.03,
	Visible = false,
	ZIndex = 10,
}, HUD.Gui)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, window)
new("UIStroke", { Color = RED, Thickness = 3 }, window)
new("UISizeConstraint", { MaxSize = Vector2.new(620, 520) }, window)
Scale.Attach(window)
text(window, { Position = UDim2.fromOffset(20, 12), Size = UDim2.new(0.7, 0, 0, 36), Text = "BLACK MARKET AUTO", FontFace = Theme.Fonts.Display, TextColor3 = RED })
text(window, { Position = UDim2.fromOffset(20, 48), Size = UDim2.new(1, -40, 0, 18), Text = "Roof-mounted hardware. Works on cops and rivals only. One weapon at a time - fire with F.", Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(200, 180, 180) })
local cashText = text(window, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -70, 0, 16), Size = UDim2.fromOffset(200, 26), Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(120, 255, 150) })
local close = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(44, 36), BackgroundColor3 = Color3.fromRGB(80, 20, 30), Text = "X", TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1) }, window)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, close)
local list = new("ScrollingFrame", { Position = UDim2.fromOffset(20, 80), Size = UDim2.new(1, -40, 1, -130), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, window)
local status = text(window, { Position = UDim2.new(0, 20, 1, -40), Size = UDim2.new(1, -40, 0, 24), Text = "", TextColor3 = Color3.fromRGB(255, 200, 80) })

local data: any = nil
local render: () -> ()

local function act(action: string, id: string)
	local ok, msg, snap = Shop:InvokeServer(action, id)
	if snap then
		data = snap
	end
	status.Text = msg or ""
	status.TextColor3 = if ok then Color3.fromRGB(120, 255, 150) else Color3.fromRGB(255, 100, 100)
	Sounds.Tick(if ok then 1.3 else 0.7, 0.5)
	render()
end

render = function()
	for _, c in list:GetChildren() do
		c:Destroy()
	end
	if not data then
		return
	end
	cashText.Text = "$" .. HUD.Commas(data.cash)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	for idx, w in Config.Weapons do
		local owned = data.weapons and data.weapons[w.id]
		local equipped = data.weapon == w.id
		local card = new("Frame", { Size = UDim2.new(1, -10, 0, 74), BackgroundColor3 = Color3.fromRGB(30, 18, 22), LayoutOrder = idx }, list)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, card)
		local sw = new("Frame", { Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = w.color }, card)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, sw)
		text(card, { Position = UDim2.fromOffset(70, 8), Size = UDim2.new(0.5, 0, 0, 24), Text = w.name, Font = Enum.Font.GothamBlack })
		text(card, { Position = UDim2.fromOffset(70, 34), Size = UDim2.new(0.62, -70, 0, 30), Text = w.desc .. "  (cooldown " .. w.cooldown .. "s)", Font = Enum.Font.Gotham, TextWrapped = true, TextColor3 = Color3.fromRGB(210, 190, 190) })
		local label, color, action
		if equipped then
			label, color, action = "UNMOUNT", Color3.fromRGB(70, 60, 60), function()
				act("EquipWeapon", "")
			end
		elseif owned then
			label, color, action = "MOUNT", Color3.fromRGB(0, 180, 200), function()
				act("EquipWeapon", w.id)
			end
		else
			label, color, action = "BUY $" .. HUD.Commas(w.price), RED, function()
				act("BuyWeapon", w.id)
			end
		end
		local b = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 40), BackgroundColor3 = color, Text = label, TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1) }, card)
		new("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
		new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, b)
		b.Activated:Connect(action)
	end
end

function BlackMarket.Toggle(open: boolean?)
	local want = if open == nil then not BlackMarket.Open else open
	if want == BlackMarket.Open then
		return
	end
	BlackMarket.Open = want
	Theme.Show(window, want, UDim2.fromOffset(0, 700))
	Sounds.Tick(if want then 1.1 else 0.85, 0.4)
	if want then
		status.Text = ""
		local ok, _, snap = Shop:InvokeServer("Get")
		if ok then
			data = snap
		end
		render()
		Input.Select(close)
	else
		Input.ClearSelection()
	end
end
close.Activated:Connect(function()
	BlackMarket.Toggle(false)
end)

-- fire the mounted weapon
function BlackMarket.Fire()
	local w = player:GetAttribute("Weapon")
	if type(w) == "string" and w ~= "" and Drive.Car then
		local ready = player:GetAttribute("WeaponReadyAt")
		if type(ready) ~= "number" or workspace:GetServerTimeNow() >= ready then
			FireWeapon:FireServer()
			Sounds.Play("rbxasset://sounds/impact_explosion_03.mp3", 0.35, 2.2)
		else
			Sounds.Tick(0.6, 0.3)
		end
	end
end

ContextActionService:BindAction("WU_Fire", function(_: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		BlackMarket.Fire()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonR1)

return BlackMarket
