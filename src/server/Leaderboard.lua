--!strict
-- Leaderboards: an all-time Most Wanted board (OrderedDataStores for total bounty and REP) plus a
-- live board for everyone on this server. Both are published as JSON StringValues in
-- ReplicatedStorage for the client UI, and the all-time board is shown on a big screen at the safehouse.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent.PlayerData)
local Session = require(script.Parent.Session)

local Leaderboard = {}

export type Entry = { name: string, value: number, id: number }

local TOP = 10
local STAT_KEYS = { "bounty", "rep" }

local stores: { [string]: OrderedDataStore } = {}
do
	local ok, err = pcall(function()
		stores.bounty = DataStoreService:GetOrderedDataStore("WantedUnbound_Bounty_v1")
		stores.rep = DataStoreService:GetOrderedDataStore("WantedUnbound_Rep_v1")
	end)
	if not ok then
		warn("[Leaderboard] OrderedDataStore unavailable, all-time board shows this server only:", err)
	end
end

local allTimeValue = Instance.new("StringValue")
allTimeValue.Name = "LeaderboardAllTime"
allTimeValue.Value = "{}"
allTimeValue.Parent = ReplicatedStorage

local serverValue = Instance.new("StringValue")
serverValue.Name = "LeaderboardServer"
serverValue.Value = "[]"
serverValue.Parent = ReplicatedStorage

local nameCache: { [number]: string } = {}
local lastSubmitted: { [number]: { [string]: number } } = {}
local boardLists: { [string]: Frame } = {}

local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		nameCache[userId] = online.DisplayName
		return online.DisplayName
	end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local name = if ok and type(result) == "string" then result else ("Racer " .. userId)
	nameCache[userId] = name
	return name
end

local function statsOf(profile: PlayerData.Profile): { [string]: number }
	return { bounty = math.floor(profile.totalBounty), rep = math.floor(profile.rep) }
end

-- Writes a player's scores to the ordered stores (yields; call from a spawned thread).
function Leaderboard.Submit(player: Player)
	local profile = PlayerData.Get(player)
	if not profile or player.UserId <= 0 then
		return
	end
	local stats = statsOf(profile)
	local prev = lastSubmitted[player.UserId] or {}
	for _, key in STAT_KEYS do
		local store = stores[key]
		if store and stats[key] > 0 and stats[key] ~= prev[key] then
			local ok, err = pcall(function()
				store:SetAsync(tostring(player.UserId), stats[key])
			end)
			if ok then
				prev[key] = stats[key]
			else
				warn("[Leaderboard] submit failed:", err)
			end
		end
	end
	lastSubmitted[player.UserId] = prev
end

local function fetchTop(key: string): { Entry }?
	local store = stores[key]
	if not store then
		return nil
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, TOP)
	end)
	if not ok then
		warn("[Leaderboard] fetch failed:", pages)
		return nil
	end
	local list: { Entry } = {}
	for _, item in (pages :: DataStorePages):GetCurrentPage() do
		local id = tonumber(item.key) or 0
		table.insert(list, { name = nameFor(id), value = item.value, id = id })
	end
	return list
end

-- Fallback when DataStores are off (Studio without API access): rank the players on this server.
local function localTop(key: string): { Entry }
	local list: { Entry } = {}
	for player, profile in PlayerData.All() do
		table.insert(list, { name = player.DisplayName, value = statsOf(profile)[key], id = player.UserId })
	end
	table.sort(list, function(a, b)
		return a.value > b.value
	end)
	while #list > TOP do
		table.remove(list)
	end
	return list
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function drawBoard(data: { [string]: { Entry } })
	for key, list in boardLists do
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local entries: { Entry } = data[key] or {}
		for rank, e in entries do
			local row = Instance.new("Frame")
			row.Name = "Row"
			row.LayoutOrder = rank
			row.Size = UDim2.new(1, 0, 1 / TOP, -6)
			row.BackgroundColor3 = if rank == 1 then Color3.fromRGB(80, 60, 10) else Color3.fromRGB(20, 22, 36)
			row.BackgroundTransparency = 0.2
			row.BorderSizePixel = 0
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 10)
			corner.Parent = row
			local rankColor = if rank == 1
				then Color3.fromRGB(255, 205, 60)
				elseif rank == 2 then Color3.fromRGB(210, 215, 230)
				elseif rank == 3 then Color3.fromRGB(215, 140, 80)
				else Color3.fromRGB(150, 156, 180)
			local function text(t: string, x: number, w: number, color: Color3, align: Enum.TextXAlignment)
				local l = Instance.new("TextLabel")
				l.BackgroundTransparency = 1
				l.Position = UDim2.fromScale(x, 0.12)
				l.Size = UDim2.fromScale(w, 0.76)
				l.Text = t
				l.TextScaled = true
				l.TextColor3 = color
				l.TextXAlignment = align
				l.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
				l.Parent = row
			end
			text("#" .. rank, 0.02, 0.12, rankColor, Enum.TextXAlignment.Left)
			text(string.upper(e.name), 0.15, 0.5, Color3.new(1, 1, 1), Enum.TextXAlignment.Left)
			text((if key == "bounty" then "$" else "") .. commas(e.value), 0.62, 0.35, rankColor, Enum.TextXAlignment.Right)
			row.Parent = list
		end
	end
end

-- Big two-column screen next to the safehouse garage.
local function buildScreen(safehouse: Vector3, parent: Instance)
	local pos = safehouse + Vector3.new(-96, 0, 30)
	local look = safehouse + Vector3.new(0, 0, -10)
	local base = CFrame.lookAt(pos, Vector3.new(look.X, pos.Y, look.Z))
	local model = Instance.new("Model")
	model.Name = "LeaderboardScreen"
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material
		p.CastShadow = name ~= "Screen"
		p.Parent = model
		return p
	end
	for _, x in { -18, 18 } do
		part("Post", Vector3.new(1.6, 34, 1.6), base * CFrame.new(x, 17, 0.8), Color3.fromRGB(40, 42, 50), Enum.Material.Metal)
	end
	part("Frame", Vector3.new(46, 26, 1.2), base * CFrame.new(0, 24, 0.5), Color3.fromRGB(18, 18, 24), Enum.Material.Metal)
	part("Trim", Vector3.new(46.4, 0.5, 1.4), base * CFrame.new(0, 37.2, 0.5), Color3.fromRGB(255, 45, 150), Enum.Material.Neon)
	local screen = part("Screen", Vector3.new(44, 24, 0.2), base * CFrame.new(0, 24, -0.2), Color3.fromRGB(6, 8, 14), Enum.Material.SmoothPlastic)
	screen.CanCollide = false

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 2.5
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(1100, 600)
	gui.MaxDistance = 700
	gui.Parent = screen
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(0, 10)
	title.Size = UDim2.new(1, 0, 0, 56)
	title.Text = "MOST WANTED - ALL TIME"
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
	title.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(0, 225, 255), Color3.fromRGB(255, 45, 150))
	grad.Parent = title
	for idx, key in STAT_KEYS do
		local col = Instance.new("Frame")
		col.BackgroundTransparency = 1
		col.Position = UDim2.fromOffset(20 + (idx - 1) * 540, 76)
		col.Size = UDim2.fromOffset(520, 510)
		col.Parent = gui
		local head = Instance.new("TextLabel")
		head.BackgroundTransparency = 1
		head.Size = UDim2.new(1, 0, 0, 36)
		head.Text = if key == "bounty" then "TOTAL BOUNTY" else "REP"
		head.TextScaled = true
		head.TextColor3 = if key == "bounty" then Color3.fromRGB(255, 60, 70) else Color3.fromRGB(0, 225, 255)
		head.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
		head.Parent = col
		local list = Instance.new("Frame")
		list.Name = "List"
		list.BackgroundTransparency = 1
		list.Position = UDim2.fromOffset(0, 44)
		list.Size = UDim2.new(1, 0, 1, -44)
		list.Parent = col
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 6)
		layout.Parent = list
		boardLists[key] = list
	end
	model.Parent = parent
end

local function refreshAllTime()
	local data: { [string]: { Entry } } = {}
	local global = true
	for _, key in STAT_KEYS do
		local list = fetchTop(key)
		if list then
			data[key] = list
		else
			global = false
			data[key] = localTop(key)
		end
	end
	allTimeValue.Value = HttpService:JSONEncode({ bounty = data.bounty, rep = data.rep, global = global, updated = os.time() })
	drawBoard(data)
end

local function refreshServer()
	local list = {}
	for player, s in Session.All() do
		local profile = s.profile
		table.insert(list, {
			name = player.DisplayName,
			id = player.UserId,
			bounty = math.floor(profile.totalBounty),
			rep = math.floor(profile.rep),
			level = (player:GetAttribute("RepLevel") :: number?) or 1,
			races = profile.racesWon,
			heat = s.heat,
			cash = profile.cash,
		})
	end
	serverValue.Value = HttpService:JSONEncode(list)
end

function Leaderboard.Init(safehouse: Vector3, parent: Instance)
	local ok, err = pcall(function()
		buildScreen(safehouse, parent)
	end)
	if not ok then
		warn("[Leaderboard] screen build failed:", err)
	end
	Players.PlayerRemoving:Connect(function(player)
		nameCache[player.UserId] = nil
		lastSubmitted[player.UserId] = nil
	end)
	-- live server board: cheap, no DataStore calls
	task.spawn(function()
		while true do
			local okServer, errServer = pcall(function()
				refreshServer()
			end)
			if not okServer then
				warn("[Leaderboard] server board error:", errServer)
			end
			task.wait(3)
		end
	end)
	-- all-time board: submit everyone online, then read the top 10 (once a minute)
	task.spawn(function()
		task.wait(8)
		while true do
			for _, player in Players:GetPlayers() do
				local okSubmit, errSubmit = pcall(function()
					Leaderboard.Submit(player)
				end)
				if not okSubmit then
					warn("[Leaderboard] submit error:", errSubmit)
				end
			end
			local okRefresh, errRefresh = pcall(function()
				refreshAllTime()
			end)
			if not okRefresh then
				warn("[Leaderboard] refresh error:", errRefresh)
			end
			task.wait(60)
		end
	end)
end

return Leaderboard
