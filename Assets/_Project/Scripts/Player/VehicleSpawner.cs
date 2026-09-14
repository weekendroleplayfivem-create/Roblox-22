using UnityEngine;
using DeliveryDisaster.Economy;
using DeliveryDisaster.Vehicles;
using DeliveryDisaster.World;

namespace DeliveryDisaster.Player
{
    /// <summary>
    /// Spawns the player's currently equipped vehicle (from UnlockManager) at a
    /// designated spawn point when the gameplay scene loads, and wires the
    /// camera to follow it. Place one instance in the gameplay scene.
    /// </summary>
    public class VehicleSpawner : MonoBehaviour
    {
        [SerializeField] private Transform spawnPoint;
        [SerializeField] private VehicleCameraFollow followCamera;

        public VehicleController CurrentVehicle { get; private set; }

        private void Start()
        {
            SpawnEquippedVehicle();
        }

        public void SpawnEquippedVehicle()
        {
            var vehicleData = UnlockManager.Instance.GetEquippedVehicle();
            if (vehicleData == null || vehicleData.VehiclePrefab == null)
            {
                Debug.LogError("[VehicleSpawner] No equipped vehicle or prefab assigned - cannot spawn player. Assign at least one starter VehicleData in UnlockManager.");
                return;
            }

            Transform resolvedSpawn = spawnPoint != null ? spawnPoint : SpawnPoint.GetRandom(SpawnPointType.PlayerStart)?.transform;
            Vector3 pos = resolvedSpawn != null ? resolvedSpawn.position : Vector3.zero;
            Quaternion rot = resolvedSpawn != null ? resolvedSpawn.rotation : Quaternion.identity;

            var instance = Instantiate(vehicleData.VehiclePrefab, pos, rot);
            CurrentVehicle = instance.GetComponent<VehicleController>();

            if (instance.GetComponent<PlayerReference>() == null)
            {
                instance.AddComponent<PlayerReference>();
            }

            if (followCamera != null)
            {
                followCamera.SetTarget(instance.transform);
            }
        }
    }
}
