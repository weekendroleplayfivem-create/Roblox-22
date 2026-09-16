--!strict
-- Minimal balance-iteration event logging. Deliberately not wired to a
-- specific external analytics backend yet - LogEvent below is the one seam
-- every other service calls through, so plugging in Roblox Analytics
-- Service or a custom DataStore-backed event queue later is a one-function
-- change instead of touching every call site across the codebase.
local AnalyticsService = {}

export type AnalyticsEvent = {
	name: string,
	userId: number?,
	properties: { [string]: any },
	timestamp: number,
}

local eventBuffer: { AnalyticsEvent } = {}
local MAX_BUFFERED_EVENTS = 500 -- backpressure valve; oldest events drop rather than growing unbounded

function AnalyticsService.LogEvent(name: string, userId: number?, properties: { [string]: any }?)
	if #eventBuffer >= MAX_BUFFERED_EVENTS then
		table.remove(eventBuffer, 1)
	end
	table.insert(eventBuffer, {
		name = name,
		userId = userId,
		properties = properties or {},
		timestamp = os.time(),
	})
end

-- Convenience wrappers for the events balance design explicitly cares about
-- (per the design bible's "why" requirement, these are the events that let
-- future difficulty/loot-table tuning be data-driven rather than guesswork).
function AnalyticsService.LogRunStart(userId: number, biomeId: string, anteLevel: number)
	AnalyticsService.LogEvent("RunStart", userId, { biome = biomeId, ante = anteLevel })
end

function AnalyticsService.LogRunEnd(userId: number, floorsCleared: number, causeOfDeath: string?, durationSeconds: number)
	AnalyticsService.LogEvent("RunEnd", userId, {
		floorsCleared = floorsCleared,
		causeOfDeath = causeOfDeath,
		durationSeconds = durationSeconds,
	})
end

function AnalyticsService.LogRelicPicked(userId: number, relicId: string, floorIndex: number)
	AnalyticsService.LogEvent("RelicPicked", userId, { relicId = relicId, floorIndex = floorIndex })
end

function AnalyticsService.Flush(): { AnalyticsEvent }
	local flushed = eventBuffer
	eventBuffer = {}
	return flushed
end

return AnalyticsService
