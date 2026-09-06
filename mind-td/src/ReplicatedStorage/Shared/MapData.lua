--!strict
--[[
	MapData
	Geometry of NEURAL OUTPOST, defined as data rather than hand-placed parts.
	MapBuilder turns this into actual geometry; EnemyManager walks the same
	waypoint tables. Nothing else should hardcode a position.

	The path forks after the main road into a LEFT and a RIGHT sector that
	rejoin at the central hub. That fork is what makes "attack the weak side"
	a real routing decision rather than a cosmetic label.
]]

export type Waypoint = {
	Name: string,
	Position: Vector3,
}

local MapData = {}

MapData.MapName = "NEURAL OUTPOST"

MapData.Colors = {
	Floor = Color3.fromRGB(48, 52, 60),
	FloorAccent = Color3.fromRGB(34, 37, 44),
	Metal = Color3.fromRGB(70, 76, 88),
	DarkMetal = Color3.fromRGB(30, 33, 39),
	EnergyBlue = Color3.fromRGB(70, 190, 255),
	EnergyCyan = Color3.fromRGB(120, 245, 235),
	WarningRed = Color3.fromRGB(255, 70, 70),
	WarningAmber = Color3.fromRGB(255, 170, 50),
	CoreGlow = Color3.fromRGB(120, 220, 255),
}

MapData.PathWidth = 16
MapData.GroundY = 0

-- Main approach: spawn gate down the main road to the fork.
MapData.MainPath = {
	{ Name = "Main_01", Position = Vector3.new(0, 0, -180) },
	{ Name = "Main_02", Position = Vector3.new(0, 0, -155) },
	{ Name = "Main_03", Position = Vector3.new(0, 0, -130) },
	{ Name = "Main_04", Position = Vector3.new(0, 0, -105) },
	{ Name = "Main_05", Position = Vector3.new(0, 0, -80) },
	{ Name = "Main_06", Position = Vector3.new(0, 0, -60) },
} :: { Waypoint }

MapData.LeftPath = {
	{ Name = "Left_01", Position = Vector3.new(-35, 0, -52) },
	{ Name = "Left_02", Position = Vector3.new(-60, 0, -32) },
	{ Name = "Left_03", Position = Vector3.new(-60, 0, -4) },
	{ Name = "Left_04", Position = Vector3.new(-44, 0, 14) },
	{ Name = "Left_05", Position = Vector3.new(-20, 0, 26) },
} :: { Waypoint }

MapData.RightPath = {
	{ Name = "Right_01", Position = Vector3.new(35, 0, -52) },
	{ Name = "Right_02", Position = Vector3.new(60, 0, -32) },
	{ Name = "Right_03", Position = Vector3.new(60, 0, -4) },
	{ Name = "Right_04", Position = Vector3.new(44, 0, 14) },
	{ Name = "Right_05", Position = Vector3.new(20, 0, 26) },
} :: { Waypoint }

-- Shared run-in from the rejoin point to the Core.
MapData.HubPath = {
	{ Name = "Hub_01", Position = Vector3.new(0, 0, 38) },
	{ Name = "Hub_02", Position = Vector3.new(0, 0, 58) },
	{ Name = "Hub_03", Position = Vector3.new(0, 0, 78) },
	{ Name = "Hub_04", Position = Vector3.new(0, 0, 94) },
} :: { Waypoint }

MapData.CorePosition = Vector3.new(0, 9, 104)
MapData.HubCenter = Vector3.new(0, 0, 58)
MapData.HubRadius = 40

-- Tower pads. Side is what AdaptiveAI counts for the left/right ratio, so it
-- has to be assigned here (authoritative) rather than inferred from a click.
MapData.TowerSpots = {
	-- Left sector
	{ Position = Vector3.new(-30, 0, -70), Side = "Left" },
	{ Position = Vector3.new(-46, 0, -52), Side = "Left" },
	{ Position = Vector3.new(-78, 0, -34), Side = "Left" },
	{ Position = Vector3.new(-42, 0, -18), Side = "Left" },
	{ Position = Vector3.new(-78, 0, 2), Side = "Left" },
	{ Position = Vector3.new(-44, 0, 4), Side = "Left" },
	{ Position = Vector3.new(-60, 0, 24), Side = "Left" },
	{ Position = Vector3.new(-26, 0, 44), Side = "Left" },
	-- Right sector
	{ Position = Vector3.new(30, 0, -70), Side = "Right" },
	{ Position = Vector3.new(46, 0, -52), Side = "Right" },
	{ Position = Vector3.new(78, 0, -34), Side = "Right" },
	{ Position = Vector3.new(42, 0, -18), Side = "Right" },
	{ Position = Vector3.new(78, 0, 2), Side = "Right" },
	{ Position = Vector3.new(44, 0, 4), Side = "Right" },
	{ Position = Vector3.new(60, 0, 24), Side = "Right" },
	{ Position = Vector3.new(26, 0, 44), Side = "Right" },
	-- Approach + hub (counted as Center; they cover both routes)
	{ Position = Vector3.new(-20, 0, -140), Side = "Center" },
	{ Position = Vector3.new(20, 0, -140), Side = "Center" },
	{ Position = Vector3.new(-20, 0, -100), Side = "Center" },
	{ Position = Vector3.new(20, 0, -100), Side = "Center" },
	{ Position = Vector3.new(-22, 0, 64), Side = "Center" },
	{ Position = Vector3.new(22, 0, 64), Side = "Center" },
	{ Position = Vector3.new(-22, 0, 86), Side = "Center" },
	{ Position = Vector3.new(22, 0, 86), Side = "Center" },
}

MapData.SpotSize = Vector3.new(8, 1, 8)

-- Builds the full waypoint list for a route. Route is "Left" or "Right".
function MapData.GetRoute(route: string): { Waypoint }
	local path: { Waypoint } = {}
	for _, waypoint in ipairs(MapData.MainPath) do
		table.insert(path, waypoint)
	end
	local branch = if route == "Left" then MapData.LeftPath else MapData.RightPath
	for _, waypoint in ipairs(branch) do
		table.insert(path, waypoint)
	end
	for _, waypoint in ipairs(MapData.HubPath) do
		table.insert(path, waypoint)
	end
	return path
end

return MapData
