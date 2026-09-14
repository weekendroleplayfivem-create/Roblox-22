using System.Collections;
using UnityEngine;
using DeliveryDisaster.Core;
using DeliveryDisaster.Economy;

namespace DeliveryDisaster.Vehicles
{
    /// <summary>
    /// Tracks vehicle health/damage. Fed by physical collisions AND directly by
    /// disaster scripts (falling debris, explosions, road collapses) via
    /// ApplyDamage(). At 0 health the vehicle breaks down for a recovery period
    /// rather than permanently ending the run - keeps the chaos fun instead of punishing.
    /// </summary>
    [RequireComponent(typeof(VehicleController))]
    public class VehicleDamageSystem : MonoBehaviour
    {
        [SerializeField] private VehicleData vehicleData;
        [SerializeField] private float collisionDamageMultiplier = 0.02f;
        [SerializeField] private float minCollisionSpeedForDamage = 3f;
        [SerializeField] private float breakdownRecoverySeconds = 6f;
        [SerializeField] private float healthRegenOnRecover = 0.35f; // fraction of max health restored after breakdown

        private VehicleController controller;
        private float maxHealth;
        private float currentHealth;
        private Coroutine recoveryRoutine;

        public float CurrentHealth01 => maxHealth <= 0f ? 1f : Mathf.Clamp01(currentHealth / maxHealth);

        private void Awake()
        {
            controller = GetComponent<VehicleController>();
            maxHealth = vehicleData != null ? vehicleData.BaseMaxHealth : 100f;
            currentHealth = maxHealth;
        }

        private void OnCollisionEnter(Collision collision)
        {
            float impactSpeed = collision.relativeVelocity.magnitude;
            if (impactSpeed < minCollisionSpeedForDamage) return;

            float rawDamage = impactSpeed * impactSpeed * collisionDamageMultiplier;
            ApplyDamage(rawDamage, collision.GetContact(0).point);
        }

        /// <summary>Primary entry point for disasters/obstacles to hurt the vehicle. Damage is a flat amount (not percent).</summary>
        public void ApplyDamage(float amount, Vector3 worldPoint)
        {
            if (amount <= 0f || currentHealth <= 0f) return;

            float insuranceReduction = UnlockManager.Instance != null
                ? Mathf.Clamp01(UnlockManager.Instance.GetTotalUpgradeEffect(UpgradeType.DisasterInsurance))
                : 0f;
            amount *= (1f - insuranceReduction);

            currentHealth = Mathf.Max(0f, currentHealth - amount);
            EventBus.Publish(new VehicleDamagedEvent(1f - CurrentHealth01, worldPoint));

            if (currentHealth <= 0f && recoveryRoutine == null)
            {
                recoveryRoutine = StartCoroutine(BreakdownAndRecover());
            }
        }

        private IEnumerator BreakdownAndRecover()
        {
            controller.SetBrokenDown(true);
            EventBus.Publish(new NotificationRequestedEvent("Vehicle broke down! Repairing...", NotificationType.Danger));

            yield return new WaitForSeconds(breakdownRecoverySeconds);

            currentHealth = maxHealth * healthRegenOnRecover;
            controller.SetBrokenDown(false);
            EventBus.Publish(new NotificationRequestedEvent("Vehicle back online.", NotificationType.Info));
            recoveryRoutine = null;
        }

        public void RepairFully()
        {
            currentHealth = maxHealth;
        }
    }
}
