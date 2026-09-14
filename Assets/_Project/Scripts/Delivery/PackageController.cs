using UnityEngine;
using DeliveryDisaster.Core;
using DeliveryDisaster.Vehicles;

namespace DeliveryDisaster.Delivery
{
    /// <summary>
    /// Represents the currently-carried package on the player's vehicle. Toggles
    /// a visual, reacts to vehicle damage/rough handling by degrading package
    /// condition, and reports condition changes back to DeliveryManager via events.
    /// Attach to the player vehicle prefab (sibling of VehicleController).
    /// </summary>
    public class PackageController : MonoBehaviour
    {
        [SerializeField] private Transform carryAnchor;
        [SerializeField] private GameObject packageVisualPrefab;
        [Tooltip("Vehicle damage-percent-this-frame above which the carried package takes condition damage.")]
        [SerializeField] private float damageThreshold = 0.05f;

        private GameObject currentVisual;
        private PackageCondition condition = PackageCondition.Pristine;

        public bool IsCarrying { get; private set; }
        public PackageCondition Condition => condition;

        private void OnEnable() => EventBus.Subscribe<VehicleDamagedEvent>(OnVehicleDamaged);
        private void OnDisable() => EventBus.Unsubscribe<VehicleDamagedEvent>(OnVehicleDamaged);

        public void PickUp()
        {
            IsCarrying = true;
            condition = PackageCondition.Pristine;

            if (packageVisualPrefab != null && carryAnchor != null)
            {
                currentVisual = Instantiate(packageVisualPrefab, carryAnchor);
                currentVisual.transform.localPosition = Vector3.zero;
            }

            EventBus.Publish(new PackageConditionChangedEvent(condition));
        }

        public void ClearPackage()
        {
            IsCarrying = false;
            if (currentVisual != null) Destroy(currentVisual);
            currentVisual = null;
        }

        private void OnVehicleDamaged(VehicleDamagedEvent evt)
        {
            if (!IsCarrying) return;
            if (evt.DamagePercent < damageThreshold) return;

            DegradeCondition();
        }

        private void DegradeCondition()
        {
            var previous = condition;
            condition = condition switch
            {
                PackageCondition.Pristine => PackageCondition.Damaged,
                PackageCondition.Damaged => PackageCondition.Destroyed,
                _ => condition
            };

            if (condition != previous)
            {
                EventBus.Publish(new PackageConditionChangedEvent(condition));
                EventBus.Publish(new NotificationRequestedEvent(
                    condition == PackageCondition.Destroyed ? "The package is destroyed!" : "The package got damaged!",
                    NotificationType.Warning));
            }
        }
    }
}
