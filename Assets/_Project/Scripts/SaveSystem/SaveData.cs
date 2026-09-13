using System;
using System.Collections.Generic;

namespace DeliveryDisaster.SaveSystem
{
    /// <summary>
    /// Plain serializable data container persisted to disk (and optionally Steam Cloud).
    /// Kept free of engine references (no Transform/Vector3) so it stays trivially
    /// JSON-serializable and stable across versions.
    /// </summary>
    [Serializable]
    public class PlayerSaveData
    {
        public int SaveVersion = 1;

        // Economy / progression
        public int Money;
        public int TotalXp;
        public int Level = 1;

        // Unlocks - store ids only, definitions live in ScriptableObjects
        public List<string> UnlockedVehicleIds = new List<string>();
        public List<string> UnlockedUpgradeIds = new List<string>();
        public List<string> UnlockedCosmeticIds = new List<string>();
        public string EquippedVehicleId = "";
        public List<string> UnlockedAchievementIds = new List<string>();

        // Lifetime stats (useful for achievements/UI)
        public int LifetimeDeliveriesCompleted;
        public int LifetimeDeliveriesFailed;
        public int LifetimeDisastersSurvived;
        public int BestSingleRunStreak;

        // Settings
        public SettingsData Settings = new SettingsData();
    }

    [Serializable]
    public class SettingsData
    {
        public float MasterVolume = 1f;
        public float MusicVolume = 0.8f;
        public float SfxVolume = 1f;
        public int QualityLevel = 2;
        public bool InvertYLook;
        public bool ScreenShakeEnabled = true;
        public bool SubtitlesEnabled = true;
        public int ResolutionWidth = 1920;
        public int ResolutionHeight = 1080;
        public bool Fullscreen = true;
    }
}
