using UnityEngine;
using DeliveryDisaster.Vehicles;

namespace DeliveryDisaster.Disasters.Types
{
    /// <summary>Rising water covers an area, dragging down vehicle speed/handling and pushing loose objects. Telegraphed by rising water-line marker.</summary>
    public class FloodDisaster : DisasterBase
    {
        [SerializeField] private float radius = 18f;
        [SerializeField] private float maxWaterHeight = 0.6f;
        [SerializeField] private float riseSpeed = 0.3f;
        [SerializeField] private float tractionPenalty = 0.5f; // multiplied into VehicleController.TractionMultiplier
        [SerializeField] private float pushForce = 4f;

        private GameObject warningMarker;
        private GameObject waterVisual;
        private float currentHeight;

        protected override void OnTelegraph()
        {
            warningMarker = SpawnPlaceholderVisual(PrimitiveType.Cylinder, new Vector3(radius * 2f, 0.02f, radius * 2f), new Color(0.2f, 0.5f, 1f, 0.35f));
        }

        protected override void OnActivate()
        {
            if (warningMarker != null) Destroy(warningMarker);
            waterVisual = SpawnPlaceholderVisual(PrimitiveType.Cylinder, new Vector3(radius * 2f, 0.01f, radius * 2f), new Color(0.1f, 0.4f, 0.9f, 0.6f));
            currentHeight = 0f;
        }

        private void Update()
        {
            if (waterVisual == null) return;

            currentHeight = Mathf.Min(maxWaterHeight, currentHeight + riseSpeed * Time.deltaTime);
            waterVisual.transform.localScale = new Vector3(radius * 2f, currentHeight, radius * 2f);
            waterVisual.transform.localPosition = new Vector3(0f, currentHeight * 0.5f, 0f);

            foreach (var col in Physics.OverlapSphere(transform.position, radius))
            {
                if (col.TryGetComponent<VehicleController>(out var vehicle))
                {
                    vehicle.TractionMultiplier = Mathf.Min(vehicle.TractionMultiplier, 1f - tractionPenalty);
                }

                if (col.attachedRigidbody != null && !col.attachedRigidbody.isKinematic)
                {
                    Vector3 pushDir = (col.attachedRigidbody.position - transform.position);
                    pushDir.y = 0f;
                    if (pushDir.sqrMagnitude > 0.01f)
                    {
                        col.attachedRigidbody.AddForce(pushDir.normalized * pushForce, ForceMode.Force);
                    }
                }
            }
        }

        protected override void OnCleanup()
        {
            if (warningMarker != null) Destroy(warningMarker);
            if (waterVisual != null) Destroy(waterVisual);

            // Restore traction for anything still in range in case they're mid-flood when it ends.
            foreach (var col in Physics.OverlapSphere(transform.position, radius))
            {
                if (col.TryGetComponent<VehicleController>(out var vehicle))
                {
                    vehicle.TractionMultiplier = 1f;
                }
            }
        }
    }
}
