using UnityEngine;
using DeliveryDisaster.Economy;

namespace DeliveryDisaster.Vehicles
{
    /// <summary>
    /// Data-driven vehicle definition. Add a new vehicle to the game by creating
    /// a new asset (Assets > Create > Delivery Disaster > Vehicle), assigning a
    /// prefab with a VehicleController on it, and dropping the asset into
    /// UnlockManager's vehicle list - no other code changes required.
    /// </summary>
    [CreateAssetMenu(fileName = "Vehicle_", menuName = "Delivery Disaster/Vehicle")]
    public class VehicleData : ScriptableObject, IUnlockableDefinition
    {
        [SerializeField] private string id;
        [SerializeField] private string displayName;
        [SerializeField, TextArea] private string description;
        [SerializeField] private Sprite icon;
        [SerializeField] private GameObject vehiclePrefab;
        [SerializeField] private bool isStarterVehicle;
        [SerializeField] private int unlockCost = 0;
        [SerializeField] private int requiredLevel = 1;

        [Header("Base Stats (before upgrades)")]
        [SerializeField] private float baseMotorTorque = 1500f;
        [SerializeField] private float baseMaxSteerAngle = 30f;
        [SerializeField] private float baseBrakeTorque = 3000f;
        [SerializeField] private int baseCargoCapacity = 1;
        [SerializeField] private float baseMaxHealth = 100f;

        public string Id => id;
        public string DisplayName => displayName;
        public string Description => description;
        public Sprite Icon => icon;
        public GameObject VehiclePrefab => vehiclePrefab;
        public bool IsStarterVehicle => isStarterVehicle;
        public int UnlockCost => unlockCost;
        public int RequiredLevel => requiredLevel;

        public float BaseMotorTorque => baseMotorTorque;
        public float BaseMaxSteerAngle => baseMaxSteerAngle;
        public float BaseBrakeTorque => baseBrakeTorque;
        public int BaseCargoCapacity => baseCargoCapacity;
        public float BaseMaxHealth => baseMaxHealth;
    }
}
