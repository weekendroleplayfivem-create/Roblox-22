--!strict
-- Hides street art pieces this player already found (they stay visible for everyone else).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shop = Remotes:WaitForChild("Shop") :: RemoteFunction
local Collected = Remotes:WaitForChild("Collected") :: RemoteEvent

local Collectibles = {}
local found: { [string]: boolean } = {}

local function hide(part: Instance)
	if part:IsA("BasePart") and found[part.Name] then
		part.Transparency = 1
		for _, d in part:GetDescendants() do
			if d:IsA("SurfaceGui") then
				d.Enabled = false
			elseif d:IsA("Light") then
				d.Enabled = false
			end
		end
	end
end

local folder: Instance? = nil
local function hookFolder()
	local map = workspace:FindFirstChild("Map")
	local f = map and map:FindFirstChild("Collectibles")
	if not f or f == folder then
		return
	end
	folder = f
	for _, p in f:GetChildren() do
		hide(p)
	end
	-- with streaming, pieces arrive as you get close
	f.ChildAdded:Connect(hide)
end

Collected.OnClientEvent:Connect(function(id: string)
	found[id] = true
	local f = folder
	local p = f and f:FindFirstChild(id)
	if p then
		hide(p)
	end
end)

task.spawn(function()
	local ok, _, snap = pcall(function()
		return Shop:InvokeServer("Get")
	end)
	if ok and type(snap) == "table" and type(snap.collected) == "table" then
		for id in snap.collected do
			found[id] = true
		end
	end
	while not folder do
		hookFolder()
		task.wait(1)
	end
end)

function Collectibles.Found(): number
	local n = 0
	for _ in found do
		n += 1
	end
	return n
end

return Collectibles
