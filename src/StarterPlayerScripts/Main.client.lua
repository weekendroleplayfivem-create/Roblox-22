--!strict
-- Client bootstrap. Client-side code in Depths predicts/animates only and
-- requests everything gameplay-authoritative via Remotes - no gameplay logic
-- belongs here, mirroring ServerScriptService/Main.server.lua's role on the
-- server side. The full HUD/menu suite (Process step 3) mounts from this
-- entry point once built; Phase 1 only establishes the Remotes handshake so
-- later UI work has a stable place to hook in rather than reaching into
-- ReplicatedStorage ad hoc from scattered scripts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
require(ReplicatedStorage.Shared.Modules.UIStyle) -- validates the shared style module loads cleanly from the client

local combatResult = remotesFolder:WaitForChild("CombatResult") :: RemoteEvent
combatResult.OnClientEvent:Connect(function(_payload)
	-- Damage-number pop/arc, hit-pause, and camera punch-in juice hook in
	-- here once the HUD is built (Process step 3).
end)
