--!nonstrict
--[[
	DamageMath.luau
	Shared so the client can PREDICT a hit (hitmarker on the same frame you click)
	while the server AUTHORS it. Both sides run identical maths, which means a
	mismatch is always a bug in the inputs - never in the formula.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root = ReplicatedStorage:WaitForChild("HyperBlast")

local CombatConfig = require(Root.Config.CombatConfig)

local DamageMath = {}

local HEAD_PARTS = {}
for _, name in CombatConfig.Hitboxes.Head.parts do
	HEAD_PARTS[name] = true
end

local LIMB_PARTS = {}
for _, name in CombatConfig.Hitboxes.Limb.parts do
	LIMB_PARTS[name] = true
end

export type HitZone = "Head" | "Torso" | "Leg"

function DamageMath.zoneForPart(partName: string): HitZone
	if HEAD_PARTS[partName] then
		return "Head"
	elseif LIMB_PARTS[partName] then
		return "Leg"
	end
	return "Torso"
end

--[[ Distance falloff. Flat inside `Start`, linear to `End`, flat after. ]]
function DamageMath.falloffMultiplier(def, distance: number): number
	local profile = def.Falloff
	if not profile or distance <= profile.Start then
		return 1
	end
	if distance >= profile.End then
		return profile.EndMultiplier
	end
	local alpha = (distance - profile.Start) / math.max(profile.End - profile.Start, 1e-3)
	return 1 + (profile.EndMultiplier - 1) * alpha
end

function DamageMath.zoneMultiplier(def, zone: HitZone): number
	if zone == "Head" then
		return def.HeadshotMultiplier or 1
	elseif zone == "Leg" then
		return def.LegMultiplier or 1
	end
	return 1
end

export type DamageContext = {
	distance: number,
	zone: HitZone,
	wallbang: boolean?,
	backstab: boolean?,
}

--[[ The one function that decides how much a bullet hurts. ]]
function DamageMath.compute(def, context: DamageContext): number
	local damage = def.Damage
	damage *= DamageMath.falloffMultiplier(def, context.distance)
	damage *= DamageMath.zoneMultiplier(def, context.zone)

	if context.backstab and def.BackstabMultiplier then
		damage *= def.BackstabMultiplier
	end
	if context.wallbang then
		damage *= CombatConfig.HitRegistration.WallbangDamageScale
	end

	-- Round to whole HP so damage numbers read cleanly and 4-shot kills stay
	-- 4-shot kills at every distance inside the flat band.
	return math.max(1, math.floor(damage + 0.5))
end

--[[ Shots-to-kill for a full-health target, used by the loadout UI. ]]
function DamageMath.shotsToKill(def, zone: HitZone, distance: number): number
	local perShot = DamageMath.compute(def, { distance = distance, zone = zone })
	local pellets = def.Pellets or 1
	return math.ceil(CombatConfig.Health.Max / math.max(perShot * pellets, 1))
end

return DamageMath
