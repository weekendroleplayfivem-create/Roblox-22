using UnityEngine;
using DeliveryDisaster.Core;
using DeliveryDisaster.Economy;

namespace DeliveryDisaster.SteamIntegration
{
    /// <summary>
    /// Listens on the EventBus and translates gameplay milestones into Steam
    /// achievement/stat calls. Keeps every other system ignorant of Steam entirely -
    /// this is the only place gameplay events get mapped to SteamIds.
    /// </summary>
    public class SteamAchievementTracker : MonoBehaviour
    {
        private int currentStreak;
        private int bestStreak;
        private bool perfectRunBroken;

        private void OnEnable()
        {
            EventBus.Subscribe<DeliveryCompletedEvent>(OnDeliveryCompleted);
            EventBus.Subscribe<DeliveryFailedEvent>(OnDeliveryFailed);
            EventBus.Subscribe<DisasterEndedEvent>(OnDisasterEnded);
            EventBus.Subscribe<LevelUpEvent>(OnLevelUp);
        }

        private void OnDisable()
        {
            EventBus.Unsubscribe<DeliveryCompletedEvent>(OnDeliveryCompleted);
            EventBus.Unsubscribe<DeliveryFailedEvent>(OnDeliveryFailed);
            EventBus.Unsubscribe<DisasterEndedEvent>(OnDisasterEnded);
            EventBus.Unsubscribe<LevelUpEvent>(OnLevelUp);
        }

        private void OnDeliveryCompleted(DeliveryCompletedEvent evt)
        {
            var steam = SteamService.Current;
            steam.IncrementStat(SteamIds.Stats.TotalDeliveries);
            steam.IncrementStat(SteamIds.Stats.TotalMoneyEarned, evt.Payout);

            currentStreak++;
            if (currentStreak > bestStreak)
            {
                bestStreak = currentStreak;
                steam.SetStat(SteamIds.Stats.BestDeliveryStreak, bestStreak);
            }

            if (steam.GetStat(SteamIds.Stats.TotalDeliveries) == 1) steam.UnlockAchievement(SteamIds.Achievements.FirstDelivery);
            if (currentStreak == 10) steam.UnlockAchievement(SteamIds.Achievements.DeliveryStreak10);
            if (currentStreak == 50) steam.UnlockAchievement(SteamIds.Achievements.DeliveryStreak50);

            steam.StoreStats();
        }

        private void OnDeliveryFailed(DeliveryFailedEvent evt)
        {
            currentStreak = 0;
            perfectRunBroken = true;
        }

        private void OnDisasterEnded(DisasterEndedEvent evt)
        {
            var steam = SteamService.Current;
            steam.IncrementStat(SteamIds.Stats.TotalDisastersSurvived);

            if (evt.Definition != null)
            {
                if (evt.Definition.DisasterId == "tornado") steam.UnlockAchievement(SteamIds.Achievements.SurvivedTornado);
                if (evt.Definition.DisasterId == "flood") steam.UnlockAchievement(SteamIds.Achievements.SurvivedFlood);
            }

            if (steam.GetStat(SteamIds.Stats.TotalDisastersSurvived) >= 5) steam.UnlockAchievement(SteamIds.Achievements.DisasterMagnet);

            steam.StoreStats();
        }

        private void OnLevelUp(LevelUpEvent evt)
        {
            if (evt.NewLevel >= 10) SteamService.Current.UnlockAchievement(SteamIds.Achievements.ReachLevel10);
            SteamService.Current.StoreStats();
        }

        /// <summary>Call at the end of a run (from GameManager.EndRun) if the run had zero failed deliveries.</summary>
        public void ReportRunEndedWithoutFailure(int deliveriesThisRun)
        {
            if (!perfectRunBroken && deliveriesThisRun > 0)
            {
                SteamService.Current.UnlockAchievement(SteamIds.Achievements.PerfectRun);
                SteamService.Current.StoreStats();
            }
            perfectRunBroken = false;
        }
    }
}
