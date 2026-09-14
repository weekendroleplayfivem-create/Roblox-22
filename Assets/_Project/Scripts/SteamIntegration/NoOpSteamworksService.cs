using System.Collections.Generic;
using UnityEngine;

namespace DeliveryDisaster.SteamIntegration
{
    /// <summary>
    /// Default ISteamworksService used whenever Steamworks.NET is not present or the
    /// SW_STEAMWORKS_NET scripting define is not set. Everything is a safe no-op or
    /// falls back to local behaviour, so the whole game (including achievement/stat
    /// calls scattered through gameplay code) works identically outside of Steam,
    /// e.g. for local testing or a non-Steam build.
    /// </summary>
    public class NoOpSteamworksService : ISteamworksService
    {
        private readonly HashSet<string> unlockedAchievements = new HashSet<string>();
        private readonly Dictionary<string, int> stats = new Dictionary<string, int>();

        public bool IsInitialized { get; private set; }
        public bool IsCloudAvailable => false;

        public void Initialize()
        {
            IsInitialized = true;
            Debug.Log("[Steam] Running with NoOpSteamworksService - Steamworks.NET not enabled. " +
                      "See Docs/SteamSetup.md to enable real Steam integration.");
        }

        public void Shutdown() => IsInitialized = false;

        public void RunCallbacks() { }

        public void UnlockAchievement(string achievementApiName)
        {
            if (string.IsNullOrEmpty(achievementApiName)) return;
            if (unlockedAchievements.Add(achievementApiName))
            {
                Debug.Log($"[Steam:NoOp] Achievement unlocked (local only): {achievementApiName}");
            }
        }

        public bool IsAchievementUnlocked(string achievementApiName) => unlockedAchievements.Contains(achievementApiName);

        public void SetStat(string statApiName, int value) => stats[statApiName] = value;

        public void IncrementStat(string statApiName, int amount = 1)
        {
            stats.TryGetValue(statApiName, out var current);
            stats[statApiName] = current + amount;
        }

        public int GetStat(string statApiName) => stats.TryGetValue(statApiName, out var value) ? value : 0;

        public void StoreStats() { }

        public bool TryReadCloudFile(string fileName, out string contents)
        {
            contents = null;
            return false;
        }

        public void WriteCloudFile(string fileName, string contents) { }
    }
}
