namespace DeliveryDisaster.SteamIntegration
{
    /// <summary>
    /// Abstraction over everything the game needs from Steamworks: achievements,
    /// stats, and cloud file mirroring. Gameplay code talks only to this
    /// interface via SteamService.Current, never to the Steamworks SDK directly,
    /// so the game compiles and runs fine with zero Steam SDK installed
    /// (NoOpSteamworksService) and only needs a scripting define flipped once
    /// Steamworks.NET is imported (see Docs/SteamSetup.md).
    /// </summary>
    public interface ISteamworksService
    {
        bool IsInitialized { get; }
        bool IsCloudAvailable { get; }

        void Initialize();
        void Shutdown();

        /// <summary>Call every frame (or on a timer) if the SDK requires callback pumping.</summary>
        void RunCallbacks();

        void UnlockAchievement(string achievementApiName);
        bool IsAchievementUnlocked(string achievementApiName);

        void SetStat(string statApiName, int value);
        void IncrementStat(string statApiName, int amount = 1);
        int GetStat(string statApiName);

        /// <summary>Push all pending achievement/stat changes to Steam. Call sparingly (e.g. on delivery complete, not every frame).</summary>
        void StoreStats();

        bool TryReadCloudFile(string fileName, out string contents);
        void WriteCloudFile(string fileName, string contents);
    }
}
