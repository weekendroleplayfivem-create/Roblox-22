using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using DeliveryDisaster.Utils;
using DeliveryDisaster.Core;
using DeliveryDisaster.Economy;
using DeliveryDisaster.Player;

namespace DeliveryDisaster.Delivery
{
    /// <summary>
    /// Owns the delivery job lifecycle: generation, pickup, the countdown timer,
    /// completion/failure, and payout. Only ever has one active job at a time
    /// (keeps the "one thing to focus on while chaos happens" arcade feel) and
    /// immediately queues the next one after a short delay.
    /// </summary>
    public class DeliveryManager : Singleton<DeliveryManager>
    {
        [Header("Job Generation")]
        [SerializeField] private int baseReward = 50;
        [SerializeField] private int baseXp = 20;
        [SerializeField] private float baseTimeLimitSeconds = 90f;
        [Tooltip("How much difficulty reduces the time limit, as a fraction per difficulty point.")]
        [SerializeField] private float timeReductionPerDifficulty = 0.06f;
        [SerializeField] private float minTimeLimitSeconds = 25f;
        [SerializeField] private float delayBetweenJobs = 3f;

        public DeliveryJob ActiveJob { get; private set; }

        private void Start()
        {
            StartCoroutine(GenerateJobAfterDelay(1f));
        }

        private void Update()
        {
            if (ActiveJob == null || GameManager.Instance.CurrentState != GameState.Playing) return;
            if (ActiveJob.Status != DeliveryStatus.AwaitingPickup && ActiveJob.Status != DeliveryStatus.InTransit) return;

            ActiveJob.TimeRemainingSeconds -= Time.deltaTime;
            EventBus.Publish(new DeliveryTimerTickEvent(Mathf.Max(0f, ActiveJob.TimeRemainingSeconds), ActiveJob.TimeLimitSeconds));

            if (ActiveJob.TimeRemainingSeconds <= 0f)
            {
                FailActiveJob("Time ran out");
            }
        }

        public void GenerateNewJob()
        {
            var locations = DeliveryLocation.All;
            var pickupCandidates = locations.Where(l => l.CanBePickup).ToList();

            if (pickupCandidates.Count == 0)
            {
                Debug.LogWarning("[DeliveryManager] No DeliveryLocation with CanBePickup found in the scene - cannot generate a job.");
                return;
            }

            var pickup = pickupCandidates[Random.Range(0, pickupCandidates.Count)];
            var dropoffCandidates = locations.Where(l => l.CanBeDropoff && l != pickup).ToList();

            if (dropoffCandidates.Count == 0)
            {
                Debug.LogWarning("[DeliveryManager] No valid dropoff distinct from pickup - cannot generate a job.");
                return;
            }

            var dropoff = dropoffCandidates[Random.Range(0, dropoffCandidates.Count)];

            float difficulty = DifficultyManager.Instance != null ? DifficultyManager.Instance.CurrentDifficulty : 1f;
            float deadlineUpgradeBonus = UnlockManager.Instance != null ? UnlockManager.Instance.GetTotalUpgradeEffect(UpgradeType.DeadlineExtender) : 0f;

            float timeLimit = Mathf.Max(minTimeLimitSeconds, baseTimeLimitSeconds * (1f - timeReductionPerDifficulty * (difficulty - 1f)) + deadlineUpgradeBonus);
            int reward = Mathf.RoundToInt(baseReward * difficulty);
            int xp = Mathf.RoundToInt(baseXp * difficulty);

            var job = new DeliveryJob(System.Guid.NewGuid().ToString("N"), pickup, dropoff, reward, xp, timeLimit);

            pickup.AssignedJob = job;
            pickup.IsAssignedAsPickup = true;
            dropoff.AssignedJob = job;
            dropoff.IsAssignedAsPickup = false;

            ActiveJob = job;
            EventBus.Publish(new DeliveryJobGeneratedEvent(job));
        }

        public bool TryPickupPackage(DeliveryLocation atLocation)
        {
            if (ActiveJob == null || atLocation != ActiveJob.Pickup || ActiveJob.Status != DeliveryStatus.AwaitingPickup) return false;

            ActiveJob.Status = DeliveryStatus.InTransit;
            PlayerReference.Active?.Package?.PickUp();

            EventBus.Publish(new PackagePickedUpEvent(ActiveJob));
            EventBus.Publish(new NotificationRequestedEvent($"Package picked up! Deliver to {ActiveJob.Dropoff.LocationName}.", NotificationType.Info));
            return true;
        }

        public bool TryDeliverPackage(DeliveryLocation atLocation)
        {
            if (ActiveJob == null || atLocation != ActiveJob.Dropoff || ActiveJob.Status != DeliveryStatus.InTransit) return false;

            var package = PlayerReference.Active?.Package;
            ActiveJob.Condition = package != null ? package.Condition : PackageCondition.Pristine;

            if (ActiveJob.Condition == PackageCondition.Destroyed)
            {
                FailActiveJob("Package destroyed");
                return false;
            }

            ActiveJob.Status = DeliveryStatus.Delivered;
            int payout = ActiveJob.CalculatePayout();

            EconomyManager.Instance.AddMoney(payout);
            ProgressionManager.Instance.AddXp(ActiveJob.BaseXp);
            DifficultyManager.Instance?.ReportDeliveryCompleted();
            GameManager.Instance.ReportDeliveryCompleted();

            EventBus.Publish(new DeliveryCompletedEvent(ActiveJob, payout, ActiveJob.BaseXp));
            EventBus.Publish(new NotificationRequestedEvent($"Delivered! +${payout}", NotificationType.Success));

            package?.ClearPackage();
            CleanUpJob();
            StartCoroutine(GenerateJobAfterDelay(delayBetweenJobs));
            return true;
        }

        public void FailActiveJob(string reason)
        {
            if (ActiveJob == null) return;

            ActiveJob.Status = DeliveryStatus.Failed;
            GameManager.Instance.ReportDeliveryFailed();

            EventBus.Publish(new DeliveryFailedEvent(ActiveJob, reason));
            EventBus.Publish(new NotificationRequestedEvent($"Delivery failed: {reason}", NotificationType.Danger));

            PlayerReference.Active?.Package?.ClearPackage();
            CleanUpJob();
            StartCoroutine(GenerateJobAfterDelay(delayBetweenJobs));
        }

        private void CleanUpJob()
        {
            if (ActiveJob == null) return;

            if (ActiveJob.Pickup != null) { ActiveJob.Pickup.AssignedJob = null; }
            if (ActiveJob.Dropoff != null) { ActiveJob.Dropoff.AssignedJob = null; }
            ActiveJob = null;
        }

        private IEnumerator GenerateJobAfterDelay(float delay)
        {
            yield return new WaitForSeconds(delay);
            GenerateNewJob();
        }
    }
}
