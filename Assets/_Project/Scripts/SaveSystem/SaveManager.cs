using System;
using System.IO;
using UnityEngine;
using DeliveryDisaster.Utils;
using DeliveryDisaster.SteamIntegration;

namespace DeliveryDisaster.SaveSystem
{
    /// <summary>
    /// Handles reading/writing PlayerSaveData to local disk as JSON, with an
    /// optional push to Steam Cloud through ISteamworksService. Local disk is
    /// always the source of truth for this build; Steam Cloud (when configured)
    /// mirrors the same file so Steam's automatic sync can move it between machines.
    /// See Docs/SteamSetup.md for what needs configuring in the Steamworks dashboard.
    /// </summary>
    public class SaveManager : Singleton<SaveManager>
    {
        private const string SaveFileName = "deliverydisaster_save.json";

        public PlayerSaveData Data { get; private set; } = new PlayerSaveData();

        public event Action OnDataLoaded;
        public event Action OnDataSaved;

        private string SavePath => Path.Combine(Application.persistentDataPath, SaveFileName);

        public void Load()
        {
            try
            {
                string json = null;

                // Prefer Steam Cloud copy when available, so progress follows the player across machines.
                if (SteamService.Current.IsCloudAvailable && SteamService.Current.TryReadCloudFile(SaveFileName, out var cloudJson))
                {
                    json = cloudJson;
                }
                else if (File.Exists(SavePath))
                {
                    json = File.ReadAllText(SavePath);
                }

                Data = string.IsNullOrEmpty(json) ? new PlayerSaveData() : JsonUtility.FromJson<PlayerSaveData>(json);

                if (Data == null)
                {
                    Data = new PlayerSaveData();
                }
            }
            catch (Exception ex)
            {
                Debug.LogError($"[SaveManager] Failed to load save file, starting fresh. {ex}");
                Data = new PlayerSaveData();
            }

            OnDataLoaded?.Invoke();
        }

        public void Save()
        {
            try
            {
                string json = JsonUtility.ToJson(Data, prettyPrint: true);
                File.WriteAllText(SavePath, json);

                if (SteamService.Current.IsCloudAvailable)
                {
                    SteamService.Current.WriteCloudFile(SaveFileName, json);
                }

                OnDataSaved?.Invoke();
            }
            catch (Exception ex)
            {
                Debug.LogError($"[SaveManager] Failed to save. {ex}");
            }
        }

        /// <summary>Resets progression only - does NOT touch settings. Used by a "reset progress" debug/menu option.</summary>
        public void ResetProgress()
        {
            var settings = Data.Settings;
            Data = new PlayerSaveData { Settings = settings };
            Save();
        }

        private void OnApplicationPause(bool paused)
        {
            if (paused) Save();
        }

        protected override void OnApplicationQuit()
        {
            Save();
            base.OnApplicationQuit();
        }
    }
}
