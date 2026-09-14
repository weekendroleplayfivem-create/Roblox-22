using System;
using UnityEngine;
using DeliveryDisaster.Core;

namespace DeliveryDisaster.Delivery
{
    /// <summary>Plain data describing a single delivery job's lifecycle. Not a MonoBehaviour - created/owned by DeliveryManager.</summary>
    [Serializable]
    public class DeliveryJob
    {
        public string JobId;
        public DeliveryLocation Pickup;
        public DeliveryLocation Dropoff;
        public int BaseReward;
        public int BaseXp;
        public float TimeLimitSeconds;
        public float TimeRemainingSeconds;
        public DeliveryStatus Status;
        public PackageCondition Condition = PackageCondition.Pristine;

        public DeliveryJob(string jobId, DeliveryLocation pickup, DeliveryLocation dropoff, int baseReward, int baseXp, float timeLimitSeconds)
        {
            JobId = jobId;
            Pickup = pickup;
            Dropoff = dropoff;
            BaseReward = baseReward;
            BaseXp = baseXp;
            TimeLimitSeconds = timeLimitSeconds;
            TimeRemainingSeconds = timeLimitSeconds;
            Status = DeliveryStatus.AwaitingPickup;
        }

        /// <summary>Final payout after condition/time penalties, before difficulty bonuses.</summary>
        public int CalculatePayout()
        {
            float conditionMultiplier = Condition switch
            {
                PackageCondition.Pristine => 1f,
                PackageCondition.Damaged => 0.5f,
                PackageCondition.Destroyed => 0f,
                _ => 1f
            };

            float timeBonus = Mathf.Clamp01(TimeRemainingSeconds / TimeLimitSeconds) * 0.25f; // up to +25% for speed
            return Mathf.RoundToInt(BaseReward * conditionMultiplier * (1f + timeBonus));
        }
    }
}
