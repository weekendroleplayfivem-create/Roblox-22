using System.Collections;
using UnityEngine;
using DeliveryDisaster.Vehicles;

namespace DeliveryDisaster.Disasters.Types
{
    /// <summary>Repeatedly drops debris from above within a radius for the disaster's duration. Debris damages the player vehicle on impact.</summary>
    public class FallingObjectsDisaster : DisasterBase
    {
        [SerializeField] private float radius = 20f;
        [SerializeField] private float dropHeight = 25f;
        [SerializeField] private float dropIntervalMin = 0.6f;
        [SerializeField] private float dropIntervalMax = 1.6f;
        [SerializeField] private float debrisDamage = 15f;
        [SerializeField] private float debrisLifetime = 6f;

        private GameObject warningMarker;
        private Coroutine dropRoutine;

        protected override void OnTelegraph()
        {
            warningMarker = SpawnPlaceholderVisual(PrimitiveType.Cylinder, new Vector3(radius * 2f, 0.03f, radius * 2f), new Color(1f, 0.2f, 0.2f, 0.35f));
        }

        protected override void OnActivate()
        {
            if (warningMarker != null) Destroy(warningMarker);
            dropRoutine = StartCoroutine(DropLoop());
        }

        private IEnumerator DropLoop()
        {
            while (true)
            {
                Vector2 offset = Random.insideUnitCircle * radius;
                Vector3 dropPos = SpawnLocation + new Vector3(offset.x, dropHeight, offset.y);
                SpawnDebris(dropPos);

                yield return new WaitForSeconds(Random.Range(dropIntervalMin, dropIntervalMax) / Mathf.Max(1f, Difficulty * 0.5f));
            }
        }

        private void SpawnDebris(Vector3 position)
        {
            var debris = GameObject.CreatePrimitive(PrimitiveType.Cube);
            debris.transform.position = position;
            debris.transform.localScale = Vector3.one * Random.Range(0.6f, 1.4f);
            debris.transform.rotation = Random.rotation;

            var rb = debris.AddComponent<Rigidbody>();
            rb.mass = 40f;

            var reporter = debris.AddComponent<FallingDebrisImpact>();
            reporter.Damage = debrisDamage * (1f + Difficulty * 0.1f);

            Destroy(debris, debrisLifetime);
        }

        protected override void OnCleanup()
        {
            if (warningMarker != null) Destroy(warningMarker);
            if (dropRoutine != null) StopCoroutine(dropRoutine);
        }
    }

    /// <summary>Small helper component so spawned debris (created at runtime, not a prefab) can report vehicle impacts back into VehicleDamageSystem.</summary>
    public class FallingDebrisImpact : MonoBehaviour
    {
        public float Damage;

        private void OnCollisionEnter(Collision collision)
        {
            if (collision.gameObject.TryGetComponent<VehicleDamageSystem>(out var damageSystem))
            {
                damageSystem.ApplyDamage(Damage, collision.GetContact(0).point);
            }
        }
    }
}
