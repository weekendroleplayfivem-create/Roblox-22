// This file only compiles against the real Steamworks API once you:
//   1. Import Steamworks.NET (https://steamworks.github.io/) into this project.
//   2. Add the scripting define symbol "SW_STEAMWORKS_NET" in
//      Project Settings > Player > Other Settings > Scripting Define Symbols.
//   3. Place a steam_appid.txt (containing your App ID) next to the built .exe
//      for local testing (Steamworks.NET reads this outside of the real Steam client).
// Until then, SteamService automatically falls back to NoOpSteamworksService and the
// rest of the game is completely unaffected. See Docs/SteamSetup.md.
#if SW_STEAMWORKS_NET
using System.IO;
using Steamworks;
using UnityEngine;

namespace DeliveryDisaster.SteamIntegration
{
    public class SteamworksNetService : ISteamworksService
    {
        public bool IsInitialized { get; private set; }
        public bool IsCloudAvailable => IsInitialized && SteamRemoteStorage.IsCloudEnabledForAccount() && SteamRemoteStorage.IsCloudEnabledForApp();

        public void Initialize()
        {
            if (!Packsize.Test())
            {
                Debug.LogError("[Steam] Packsize test failed - Steamworks.NET is likely mismatched with your platform target.");
            }

            if (!DllCheck.Test())
            {
                Debug.LogError("[Steam] DllCheck test failed - native Steamworks binaries are missing/misplaced.");
            }

            try
            {
                IsInitialized = SteamAPI.Init();
                if (!IsInitialized)
                {
                    Debug.LogWarning("[Steam] SteamAPI.Init() failed. Is Steam running and is steam_appid.txt correct?");
                }
                else
                {
                    SteamUserStats.RequestCurrentStats();
                }
            }
            catch (System.DllNotFoundException ex)
            {
                Debug.LogError($"[Steam] Native Steamworks library not found: {ex.Message}");
                IsInitialized = false;
            }
        }

        public void Shutdown()
        {
            if (IsInitialized) SteamAPI.Shutdown();
            IsInitialized = false;
        }

        public void RunCallbacks()
        {
            if (IsInitialized) SteamAPI.RunCallbacks();
        }

        public void UnlockAchievement(string achievementApiName)
        {
            if (!IsInitialized || string.IsNullOrEmpty(achievementApiName)) return;
            SteamUserStats.SetAchievement(achievementApiName);
            StoreStats();
        }

        public bool IsAchievementUnlocked(string achievementApiName)
        {
            if (!IsInitialized) return false;
            return SteamUserStats.GetAchievement(achievementApiName, out bool achieved) && achieved;
        }

        public void SetStat(string statApiName, int value)
        {
            if (!IsInitialized) return;
            SteamUserStats.SetStat(statApiName, value);
        }

        public void IncrementStat(string statApiName, int amount = 1)
        {
            if (!IsInitialized) return;
            SteamUserStats.GetStat(statApiName, out int current);
            SteamUserStats.SetStat(statApiName, current + amount);
        }

        public int GetStat(string statApiName)
        {
            if (!IsInitialized) return 0;
            SteamUserStats.GetStat(statApiName, out int value);
            return value;
        }

        public void StoreStats()
        {
            if (IsInitialized) SteamUserStats.StoreStats();
        }

        public bool TryReadCloudFile(string fileName, out string contents)
        {
            contents = null;
            if (!IsCloudAvailable || !SteamRemoteStorage.FileExists(fileName)) return false;

            int size = SteamRemoteStorage.GetFileSize(fileName);
            var buffer = new byte[size];
            int read = SteamRemoteStorage.FileRead(fileName, buffer, size);
            if (read <= 0) return false;

            contents = System.Text.Encoding.UTF8.GetString(buffer, 0, read);
            return true;
        }

        public void WriteCloudFile(string fileName, string contents)
        {
            if (!IsCloudAvailable) return;
            var bytes = System.Text.Encoding.UTF8.GetBytes(contents);
            SteamRemoteStorage.FileWrite(fileName, bytes, bytes.Length);
        }
    }
}
#endif
