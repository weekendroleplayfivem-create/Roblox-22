using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using DeliveryDisaster.Utils;
using DeliveryDisaster.SaveSystem;
using DeliveryDisaster.Core;
using DeliveryDisaster.Vehicles;

namespace DeliveryDisaster.Economy
{
    /// <summary>
    /// Central shop/unlock authority for vehicles, upgrades and cosmetics.
    /// Drop new ScriptableObject assets into the relevant array in the Inspector
    /// and they immediately become purchasable/unlockable - no code changes.
    /// </summary>
    public class UnlockManager : Singleton<UnlockManager>
    {
        [SerializeField] private List<VehicleData> allVehicles = new List<VehicleData>();
        [SerializeField] private List<UpgradeData> allUpgrades = new List<UpgradeData>();
        [SerializeField] private List<CosmeticData> allCosmetics = new List<CosmeticData>();

        public IReadOnlyList<VehicleData> AllVehicles => allVehicles;
        public IReadOnlyList<UpgradeData> AllUpgrades => allUpgrades;
        public IReadOnlyList<CosmeticData> AllCosmetics => allCosmetics;

        private void Start()
        {
            // Starter vehicle is always unlocked for free so a fresh save has something to drive.
            var starter = allVehicles.FirstOrDefault(v => v.IsStarterVehicle);
            if (starter != null && !IsUnlocked(starter))
            {
                SaveManager.Instance.Data.UnlockedVehicleIds.Add(starter.Id);
                SaveManager.Instance.Data.EquippedVehicleId = starter.Id;
            }
        }

        public bool IsUnlocked(IUnlockableDefinition def)
        {
            var data = SaveManager.Instance.Data;
            return def switch
            {
                VehicleData => data.UnlockedVehicleIds.Contains(def.Id),
                UpgradeData => data.UnlockedUpgradeIds.Contains(def.Id),
                CosmeticData => data.UnlockedCosmeticIds.Contains(def.Id),
                _ => false
            };
        }

        public bool CanUnlock(IUnlockableDefinition def)
        {
            if (IsUnlocked(def)) return false;
            if (ProgressionManager.Instance.Level < def.RequiredLevel) return false;
            return EconomyManager.Instance.CanAfford(def.UnlockCost);
        }

        public bool TryUnlock(IUnlockableDefinition def)
        {
            if (!CanUnlock(def)) return false;
            if (!EconomyManager.Instance.TrySpend(def.UnlockCost)) return false;

            var data = SaveManager.Instance.Data;
            switch (def)
            {
                case VehicleData: data.UnlockedVehicleIds.Add(def.Id); break;
                case UpgradeData: data.UnlockedUpgradeIds.Add(def.Id); break;
                case CosmeticData: data.UnlockedCosmeticIds.Add(def.Id); break;
            }

            EventBus.Publish(new ItemUnlockedEvent(def.Id, def.DisplayName));
            EventBus.Publish(new NotificationRequestedEvent($"Unlocked: {def.DisplayName}!", NotificationType.Success));

            if (def is VehicleData && allVehicles.Count > 0 && allVehicles.All(v => IsUnlocked(v)))
            {
                SteamIntegration.SteamService.Current.UnlockAchievement(SteamIntegration.SteamIds.Achievements.AllVehiclesUnlocked);
                SteamIntegration.SteamService.Current.StoreStats();
            }

            SaveManager.Instance.Save();
            return true;
        }

        public bool TryEquipVehicle(VehicleData vehicle)
        {
            if (!IsUnlocked(vehicle)) return false;
            SaveManager.Instance.Data.EquippedVehicleId = vehicle.Id;
            SaveManager.Instance.Save();
            return true;
        }

        public VehicleData GetEquippedVehicle()
        {
            string id = SaveManager.Instance.Data.EquippedVehicleId;
            return allVehicles.FirstOrDefault(v => v.Id == id) ?? allVehicles.FirstOrDefault(v => v.IsStarterVehicle);
        }

        /// <summary>Sum of all unlocked upgrade effect values for a given type - used by VehicleController/DeliveryManager.</summary>
        public float GetTotalUpgradeEffect(UpgradeType type)
        {
            var data = SaveManager.Instance.Data;
            return allUpgrades
                .Where(u => u.Type == type && data.UnlockedUpgradeIds.Contains(u.Id))
                .Sum(u => u.EffectValue);
        }
    }
}
