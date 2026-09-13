using UnityEngine;
using DeliveryDisaster.Vehicles;
using DeliveryDisaster.World;

namespace DeliveryDisaster.Disasters.Types
{
    /// <summary>Picks a nearby NPC vehicle (or just detonates at the spawn point if none are around) and blows it up, damaging/pushing anything in the blast radius including the player.</summary>
    public class VehicleExplosionDisaster : DisasterBase
    {
        [SerializeField] private float searchRadius = 25f;
        [SerializeField] private float blastRadius = 9f;
        [SerializeField] private float blastForce = 20f;
        [SerializeField] private float blastDamage = 35f;

        private GameObject warningMarker;
        private NPCVehicleAI targetNpc;

        protected override void OnTelegraph()
        {
            targetNpc = FindNearbyNpc();
            Vector3 markerPos = targetNpc != null ? targetNpc.transform.position : SpawnLocation;

            warningMarker = SpawnPlaceholderVisual(PrimitiveType.Sphere, Vector3.one * 1.5f, new Color(1f, 0.5f, 0f, 0.7f));
            warningMarker.transform.position = markerPos;
        }

        private NPCVehicleAI FindNearbyNpc()
        {
            float closest = float.MaxValue;
            NPCVehicleAI best = null;

            foreach (var npc in NPCVehicleAI.All)
            {
                if (npc == null) continue;
                float dist = Vector3.Distance(npc.transform.position, SpawnLocation);
                if (dist <= searchRadius && dist < closest)
                {
                    closest = dist;
                    best = npc;
                }
            }

            return best;
        }

        protected override void OnActivate()
        {
            if (warningMarker != null) Destroy(warningMarker);

            Vector3 blastCenter = targetNpc != null ? targetNpc.transform.position : SpawnLocation;

            if (targetNpc != null)
            {
                targetNpc.Explode();
            }

            var fireball = SpawnPlaceholderVisual(PrimitiveType.Sphere, Vector3.one * blastRadius * 0.6f, new Color(1f, 0.35f, 0f, 0.85f));
            fireball.transform.position = blastCenter;
            fireball.transform.SetParent(null); // detach so it doesn't move with this disaster's transform

            foreach (var col in Physics.OverlapSphere(blastCenter, blastRadius))
            {
                if (col.attachedRigidbody != null && !col.attachedRigidbody.isKinematic)
                {
                    Vector3 dir = (col.attachedRigidbody.position - blastCenter);
                    float dist = Mathf.Max(0.5f, dir.magnitude);
                    col.attachedRigidbody.AddForce(dir.normalized * blastForce * Difficulty / dist, ForceMode.Impulse);
                }

                if (col.TryGetComponent<VehicleDamageSystem>(out var damage))
                {
                    float falloff = 1f - Mathf.Clamp01(Vector3.Distance(col.transform.position, blastCenter) / blastRadius);
                    damage.ApplyDamage(blastDamage * falloff, blastCenter);
                }
            }

            Destroy(fireball, 1.2f);
        }

        protected override void OnCleanup()
        {
            if (warningMarker != null) Destroy(warningMarker);
        }
    }
}
