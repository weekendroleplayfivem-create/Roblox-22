--[[
	RaycastUtil
	Central place for world-container names and raycast helpers so that the
	client (prediction) and server (validation) raycast against the same
	geometry with the same rules.

	Conventions:
	  * Arena geometry lives in workspace.Arena, lobby geometry in workspace.Lobby.
	  * Ability objects (barriers, fields) live in workspace.AbilityObjects.
	  * Cosmetic client effects live in workspace.Effects (never raycast).
	  * Every combat character (players + bots) has the attribute "CombatantId".
	  * Barriers are tagged "ShotBlocker" and carry "OwnerId" + "Team" attributes.
	  * Decoys are tagged "Decoy".
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local RaycastUtil = {}

RaycastUtil.Containers = {
	Arena = "Arena",
	Lobby = "Lobby",
	AbilityObjects = "AbilityObjects",
	Effects = "Effects",
	Bots = "Bots",
}

RaycastUtil.Tags = {
	ShotBlocker = "ShotBlocker",
	Decoy = "Decoy",
	JumpPad = "JumpPad",
	GravityField = "GravityField",
	KillZone = "KillZone",
	-- Decorative animation tags (animated client-side by Effects/MapAnimator).
	Spin = "VR_Spin",
	Bob = "VR_Bob",
	Pulse = "VR_Pulse",
	Flicker = "VR_Flicker",
}

-- Returns a workspace container folder. The server creates every container at
-- startup; clients wait for replication (except the client-only Effects folder).
function RaycastUtil.GetContainer(name: string): Folder
	local existing = workspace:FindFirstChild(name)
	if existing then
		return existing :: Folder
	end
	if RunService:IsClient() and name ~= RaycastUtil.Containers.Effects then
		return workspace:WaitForChild(name) :: Folder
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	return folder
end

-- Walks up from a hit part to the model that represents a combatant or decoy.
function RaycastUtil.FindTargetModel(part: Instance?): Model?
	local current = part
	while current and current ~= workspace do
		if current:IsA("Model") then
			if current:GetAttribute("CombatantId") ~= nil or CollectionService:HasTag(current, RaycastUtil.Tags.Decoy) then
				return current
			end
		end
		current = current.Parent
	end
	return nil
end

-- True when a blocker should stop shots from `shooterTeam`/`shooterId`.
-- Barriers only block enemy fire; your own team's shots pass through.
function RaycastUtil.BlocksShooter(blocker: Instance, shooterTeam: string?, shooterId: number?): boolean
	local ownerId = blocker:GetAttribute("OwnerId")
	if ownerId ~= nil and ownerId == shooterId then
		return false
	end
	local blockerTeam = blocker:GetAttribute("Team")
	if shooterTeam and shooterTeam ~= "" and blockerTeam == shooterTeam then
		return false
	end
	return true
end

local function friendlyBlockers(shooterTeam: string?, shooterId: number?): { Instance }
	local list = {}
	for _, blocker in CollectionService:GetTagged(RaycastUtil.Tags.ShotBlocker) do
		if not RaycastUtil.BlocksShooter(blocker, shooterTeam, shooterId) then
			table.insert(list, blocker)
		end
	end
	return list
end

-- Params that only hit static world geometry plus enemy barriers. Used for
-- line-of-sight validation, spawn visibility and bot perception.
function RaycastUtil.WorldParams(shooterTeam: string?, shooterId: number?): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local include: { Instance } = {
		RaycastUtil.GetContainer(RaycastUtil.Containers.Arena),
		RaycastUtil.GetContainer(RaycastUtil.Containers.Lobby),
	}
	for _, blocker in CollectionService:GetTagged(RaycastUtil.Tags.ShotBlocker) do
		if RaycastUtil.BlocksShooter(blocker, shooterTeam, shooterId) then
			table.insert(include, blocker)
		end
	end
	params.FilterDescendantsInstances = include
	params.IgnoreWater = true
	return params
end

-- Params for a full combat ray: hits everything except the shooter, effects
-- and friendly barriers.
function RaycastUtil.CombatParams(ignore: { Instance }, shooterTeam: string?, shooterId: number?): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = table.clone(ignore)
	table.insert(exclude, RaycastUtil.GetContainer(RaycastUtil.Containers.Effects))
	for _, blocker in friendlyBlockers(shooterTeam, shooterId) do
		table.insert(exclude, blocker)
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	return params
end

function RaycastUtil.Cast(origin: Vector3, direction: Vector3, params: RaycastParams): RaycastResult?
	return workspace:Raycast(origin, direction, params)
end

-- True when nothing in the world blocks the segment from `a` to `b`
-- (allowing `tolerance` studs of slack at the far end).
function RaycastUtil.HasLineOfSight(a: Vector3, b: Vector3, params: RaycastParams, tolerance: number?): boolean
	local offset = b - a
	local distance = offset.Magnitude
	if distance < 1e-3 then
		return true
	end
	local result = workspace:Raycast(a, offset, params)
	if not result then
		return true
	end
	return (result.Position - a).Magnitude >= distance - (tolerance or 0.5)
end

return RaycastUtil
