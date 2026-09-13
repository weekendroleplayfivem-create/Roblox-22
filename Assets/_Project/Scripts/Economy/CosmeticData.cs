using UnityEngine;

namespace DeliveryDisaster.Economy
{
    public enum CosmeticSlot
    {
        VehiclePaint,
        VehicleDecal,
        DriverOutfit,
        Hat
    }

    /// <summary>Purely visual unlock - no gameplay effect. Create via Assets > Create > Delivery Disaster > Cosmetic.</summary>
    [CreateAssetMenu(fileName = "Cosmetic_", menuName = "Delivery Disaster/Cosmetic")]
    public class CosmeticData : ScriptableObject, IUnlockableDefinition
    {
        [SerializeField] private string id;
        [SerializeField] private string displayName;
        [SerializeField] private Sprite icon;
        [SerializeField] private int unlockCost = 250;
        [SerializeField] private int requiredLevel = 1;
        [SerializeField] private CosmeticSlot slot;
        [Tooltip("Material swapped onto the vehicle/driver renderer when this cosmetic is equipped.")]
        [SerializeField] private Material appliedMaterial;

        public string Id => id;
        public string DisplayName => displayName;
        public Sprite Icon => icon;
        public int UnlockCost => unlockCost;
        public int RequiredLevel => requiredLevel;
        public CosmeticSlot Slot => slot;
        public Material AppliedMaterial => appliedMaterial;
    }
}
