--[[
	Types
	Shared type definitions used across client and server modules.
]]

export type ModeId = "TeamDeathmatch" | "FreeForAll" | "GunGame"
export type MatchPhase = "Lobby" | "Starting" | "Loading" | "Countdown" | "Active" | "Results"
export type WeaponSlot = "Primary" | "Secondary"
export type AbilitySlot = "Movement" | "Tactical"

-- Payload the client sends with RequestFire. The server re-validates all of it.
export type HitClaim = {
	Target: Model,
	Part: BasePart,
	Position: Vector3,
	Pellet: number?,
}

export type FireRequest = {
	Weapon: string,
	Shot: number,
	Origin: Vector3,
	Direction: Vector3,
	Pellets: { Vector3 }?,
	Hits: { HitClaim }?,
}

export type ScoreboardEntry = {
	Id: number,
	Name: string,
	Team: string?,
	Kills: number,
	Deaths: number,
	Assists: number,
	Score: number,
	Ping: number,
	IsBot: boolean,
	Level: number?,
	Banner: string?,
}

export type MatchState = {
	Phase: MatchPhase,
	Mode: ModeId?,
	Map: string?,
	PhaseEndsAt: number?,
	TeamScores: { [string]: number }?,
	ScoreLimit: number?,
	Participants: { number }?,
}

return {}
