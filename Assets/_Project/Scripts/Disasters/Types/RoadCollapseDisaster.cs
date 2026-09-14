using UnityEngine;
using DeliveryDisaster.Vehicles;

namespace DeliveryDisaster.Disasters.Types
{
    /// <summary>Opens a hazardous pothole/sinkhole in the road. Driving into it damages and sharply slows the vehicle. Blocks the direct path, forcing a detour.</summary>
    public class RoadCollapseDisaster : DisasterBase
    {
        [SerializeField] private float holeRadius = 4f;
        [SerializeField] private float impactDamage = 25f;
        [SerializeField] private float slowMultiplier = 0.2f;
        [SerializeField] private float slowDuration = 2.5f;

        private GameObject warningMarker;
        private GameObject holeVisual;
        private SphereCollider triggerZone;

        protected override void OnTelegraph()
        {
            warningMarker = SpawnPlaceholderVisual(PrimitiveType.Cylinder, new Vector3(holeRadius * 2f, 0.02f, holeRadius * 2f), new Color(0.9f, 0.7f, 0f, 0.5f));
        }

        protected override void OnActivate()
        {
            if (warningMarker != null) Destroy(warningMarker);

            holeVisual = SpawnPlaceholderVisual(PrimitiveType.Cylinder, new Vector3(holeRadius * 2f, 0.3f, holeRadius * 2f), new Color(0.05f, 0.05f, 0.05f, 1f));
            holeVisual.transform.localPosition = new Vector3(0f, -0.1f, 0f);

            var triggerObj = new GameObject("CollapseTrigger");
            triggerObj.transform.SetParent(transform, false);
            triggerZone = triggerObj.AddComponent<SphereCollider>();
            triggerZone.isTrigger = true;
            triggerZone.radius = holeRadius * 0.85f;
            var forwarder = triggerObj.AddComponent<CollapseTriggerForwarder>();
            forwarder.Owner = this;
        }

        public void OnVehicleEnteredHole(VehicleController vehicle)
        {
            if (vehicle.TryGetComponent<VehicleDamageSystem>(out var damage))
            {
                damage.ApplyDamage(impactDamage, vehicle.transform.position);
            }

            StartCoroutineSafe(SlowVehicleTemporarily(vehicle));
        }

        private void StartCoroutineSafe(System.Collections.IEnumerator routine) => StartCoroutine(routine);

        private System.Collections.IEnumerator SlowVehicleTemporarily(VehicleController vehicle)
        {
            float original = vehicle.TractionMultiplier;
            vehicle.TractionMultiplier = Mathf.Min(vehicle.TractionMultiplier, slowMultiplier);
            yield return new WaitForSeconds(slowDuration);
            if (vehicle != null) vehicle.TractionMultiplier = original;
        }

        protected override void OnCleanup()
        {
            if (warningMarker != null) Destroy(warningMarker);
            if (holeVisual != null) Destroy(holeVisual);
        }
    }

    /// <summary>Forwards trigger events to the owning disaster - lets the disaster keep its logic in one place instead of scattering MonoBehaviours.</summary>
    public class CollapseTriggerForwarder : MonoBehaviour
    {
        public RoadCollapseDisaster Owner;

        private void OnTriggerEnter(Collider other)
        {
            if (other.attachedRigidbody != null && other.attachedRigidbody.TryGetComponent<VehicleController>(out var vehicle))
            {
                Owner.OnVehicleEnteredHole(vehicle);
            }
        }
    }
}
