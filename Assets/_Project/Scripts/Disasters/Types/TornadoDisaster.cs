using UnityEngine;
using DeliveryDisaster.Vehicles;

namespace DeliveryDisaster.Disasters.Types
{
    /// <summary>Wandering funnel that sucks nearby rigidbodies inward/upward and flings them around. Telegraphed by a dust-ring warning marker.</summary>
    public class TornadoDisaster : DisasterBase
    {
        [SerializeField] private float radius = 12f;
        [SerializeField] private float pullForce = 18f;
        [SerializeField] private float liftForce = 6f;
        [SerializeField] private float swirlForce = 10f;
        [SerializeField] private float wanderSpeed = 3f;
        [SerializeField] private LayerMask affectedLayers = ~0;

        private GameObject warningMarker;
        private GameObject funnelVisual;
        private Vector3 wanderTarget;

        protected override void OnTelegraph()
        {
            warningMarker = SpawnPlaceholderVisual(PrimitiveType.Cylinder, new Vector3(radius * 2f, 0.05f, radius * 2f), new Color(1f, 0.6f, 0f, 0.4f));
            PickNewWanderTarget();
        }

        protected override void OnActivate()
        {
            if (warningMarker != null) Destroy(warningMarker);
            funnelVisual = SpawnPlaceholderVisual(PrimitiveType.Cylinder, new Vector3(2f, 6f, 2f), new Color(0.6f, 0.6f, 0.6f, 0.85f));
            funnelVisual.transform.localPosition = new Vector3(0f, 3f, 0f);
        }

        private void Update()
        {
            if (funnelVisual == null) return;

            // Wander slowly so the player can react/avoid rather than it being a stationary damage sponge.
            transform.position = Vector3.MoveTowards(transform.position, wanderTarget, wanderSpeed * Time.deltaTime);
            if (Vector3.Distance(transform.position, wanderTarget) < 0.5f) PickNewWanderTarget();

            foreach (var col in Physics.OverlapSphere(transform.position, radius, affectedLayers))
            {
                if (!col.attachedRigidbody) continue;

                Vector3 toCenter = transform.position - col.attachedRigidbody.position;
                toCenter.y = 0f;
                float distance01 = Mathf.Clamp01(1f - toCenter.magnitude / radius);

                Vector3 pull = toCenter.normalized * pullForce * distance01;
                Vector3 lift = Vector3.up * liftForce * distance01;
                Vector3 swirl = Vector3.Cross(Vector3.up, toCenter).normalized * swirlForce * distance01;

                col.attachedRigidbody.AddForce((pull + lift + swirl) * Difficulty, ForceMode.Force);
            }
        }

        private void PickNewWanderTarget()
        {
            Vector2 offset = Random.insideUnitCircle * radius * 1.5f;
            wanderTarget = SpawnLocation + new Vector3(offset.x, 0f, offset.y);
        }

        protected override void OnCleanup()
        {
            if (warningMarker != null) Destroy(warningMarker);
            if (funnelVisual != null) Destroy(funnelVisual);
        }
    }
}
