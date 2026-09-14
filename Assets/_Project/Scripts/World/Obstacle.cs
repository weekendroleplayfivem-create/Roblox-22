using UnityEngine;
using DeliveryDisaster.Vehicles;

namespace DeliveryDisaster.World
{
    /// <summary>
    /// Generic static/dynamic hazard the player can collide with (traffic cones,
    /// crashed cars, barriers spawned by disasters). Add to any obstacle prefab;
    /// damage-on-contact is optional (set contactDamage to 0 for a purely
    /// path-blocking obstacle like a construction barrier).
    /// </summary>
    public class Obstacle : MonoBehaviour
    {
        [SerializeField] private float contactDamage = 10f;
        [SerializeField] private float minImpactSpeed = 2f;

        private void OnCollisionEnter(Collision collision)
        {
            if (contactDamage <= 0f) return;
            if (collision.relativeVelocity.magnitude < minImpactSpeed) return;

            if (collision.gameObject.TryGetComponent<VehicleDamageSystem>(out var damage))
            {
                damage.ApplyDamage(contactDamage, collision.GetContact(0).point);
            }
        }
    }
}
