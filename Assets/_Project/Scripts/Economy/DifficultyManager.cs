using UnityEngine;
using DeliveryDisaster.Utils;

namespace DeliveryDisaster.Economy
{
    /// <summary>
    /// Produces a single normalized-ish "difficulty" value that DeliveryManager
    /// (tighter deadlines, longer distances) and DisasterManager (spawn frequency,
    /// severity weighting) both read from. Keeping difficulty in one place means
    /// tuning the game's pacing is a matter of editing curves here, not hunting
    /// through every system that scales with it.
    /// </summary>
    public class DifficultyManager : Singleton<DifficultyManager>
    {
        [SerializeField] private float startingDifficulty = 1f;
        [SerializeField] private float difficultyPerMinute = 0.15f;
        [SerializeField] private float difficultyPerDelivery = 0.05f;
        [SerializeField] private float maxDifficulty = 5f;

        private float runElapsedSeconds;
        private int deliveriesCompletedThisRun;

        public float CurrentDifficulty { get; private set; }

        protected override void Awake()
        {
            base.Awake();
            ResetRun();
        }

        private void Update()
        {
            if (Core.GameManager.Instance != null && Core.GameManager.Instance.CurrentState != Core.GameState.Playing) return;

            runElapsedSeconds += Time.deltaTime;
            Recalculate();
        }

        public void ResetRun()
        {
            runElapsedSeconds = 0f;
            deliveriesCompletedThisRun = 0;
            Recalculate();
        }

        public void ReportDeliveryCompleted()
        {
            deliveriesCompletedThisRun++;
            Recalculate();
        }

        private void Recalculate()
        {
            float minutes = runElapsedSeconds / 60f;
            CurrentDifficulty = Mathf.Min(
                maxDifficulty,
                startingDifficulty + minutes * difficultyPerMinute + deliveriesCompletedThisRun * difficultyPerDelivery);
        }
    }
}
