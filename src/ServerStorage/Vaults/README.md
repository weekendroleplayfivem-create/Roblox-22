# Vaults

Hand-placed prefab `Model`s for boss arenas, secret rooms, and shrine vaults,
seeded into procedurally generated floors by `DungeonGenerator._seedVaults`
(placement) and `InstanceBuilder` (geometry stamping — not yet built).

Each biome's boss arena vault should be named to match its `BossDef.arenaVaultId`
in `ReplicatedStorage/Shared/Data/Bosses.lua` (e.g. `Vault_CryptBossArena`).
These must be authored directly in Roblox Studio, so this directory is empty
until a Studio-connected session builds them.
