using UnityEngine;
using DeliveryDisaster.Vehicles;
using DeliveryDisaster.Delivery;

namespace DeliveryDisaster.Player
{
    /// <summary>
    /// Simple static lookup for "the player's current vehicle" so disasters,
    /// NPC AI and UI can find it without an expensive FindObjectOfType call
    /// every frame. Place on the player vehicle root; re-registers automatically
    /// whenever the player swaps vehicles (see VehicleSpawner).
    /// </summary>
    public class PlayerReference : MonoBehaviour
    {
        public static PlayerReference Active { get; private set; }

        public VehicleController Vehicle { get; private set; }
        public Rigidbody Rigidbody { get; private set; }
        public PackageController Package { get; private set; }

        private void Awake()
        {
            Vehicle = GetComponent<VehicleController>();
            Rigidbody = GetComponent<Rigidbody>();
            Package = GetComponent<PackageController>();
        }

        private void OnEnable() => Active = this;

        private void OnDisable()
        {
            if (Active == this) Active = null;
        }
    }
}
