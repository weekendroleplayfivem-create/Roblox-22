using UnityEngine;
using DeliveryDisaster.Utils;
using DeliveryDisaster.SaveSystem;
using DeliveryDisaster.Core;

namespace DeliveryDisaster.Economy
{
    /// <summary>
    /// Owns XP and level progression. Level curve is a simple accelerating cost
    /// (tweak XpForLevel to retune pacing without touching any calling code).
    /// </summary>
    public class ProgressionManager : Singleton<ProgressionManager>
    {
        [Tooltip("Base XP required for level 2. Each subsequent level scales by LevelCurveExponent.")]
        [SerializeField] private int baseXpForLevel2 = 100;
        [SerializeField] private float levelCurveExponent = 1.35f;
        [SerializeField] private int maxLevel = 50;

        public int Level => SaveManager.Instance.Data.Level;
        public int TotalXp => SaveManager.Instance.Data.TotalXp;

        /// <summary>Total XP required to REACH the given level from zero.</summary>
        public int XpRequiredForLevel(int level)
        {
            if (level <= 1) return 0;
            return Mathf.RoundToInt(baseXpForLevel2 * Mathf.Pow(level - 1, levelCurveExponent));
        }

        public float ProgressToNextLevel()
        {
            int level = Level;
            if (level >= maxLevel) return 1f;

            int currentLevelXp = XpRequiredForLevel(level);
            int nextLevelXp = XpRequiredForLevel(level + 1);
            int span = Mathf.Max(1, nextLevelXp - currentLevelXp);
            return Mathf.Clamp01((TotalXp - currentLevelXp) / (float)span);
        }

        public void AddXp(int amount)
        {
            if (amount <= 0) return;

            var data = SaveManager.Instance.Data;
            data.TotalXp += amount;
            EventBus.Publish(new XpChangedEvent(data.TotalXp, amount));

            while (data.Level < maxLevel && data.TotalXp >= XpRequiredForLevel(data.Level + 1))
            {
                data.Level++;
                EventBus.Publish(new LevelUpEvent(data.Level));
                EventBus.Publish(new NotificationRequestedEvent($"Level up! You're now level {data.Level}.", NotificationType.Success));
            }
        }
    }
}
