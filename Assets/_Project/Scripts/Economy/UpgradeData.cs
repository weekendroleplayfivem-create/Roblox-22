using UnityEngine;

namespace DeliveryDisaster.Economy
{
    public enum UpgradeType
    {
        EngineSpeed,
        Handling,
        CargoCapacity,
        DisasterInsurance, // reduces damage/penalty taken from disaster effects
        DeadlineExtender    // grants extra seconds per delivery
    }

    /// <summary>
    /// Data-driven vehicle/delivery upgrade. Create new upgrades entirely via
    /// Assets > Create > Delivery Disaster > Upgrade - no code changes needed.
    /// </summary>
    [CreateAssetMenu(fileName = "Upgrade_", menuName = "Delivery Disaster/Upgrade")]
    public class UpgradeData : ScriptableObject, IUnlockableDefinition
    {
        [SerializeField] private string id;
        [SerializeField] private string displayName;
        [SerializeField, TextArea] private string description;
        [SerializeField] private Sprite icon;
        [SerializeField] private int unlockCost = 500;
        [SerializeField] private int requiredLevel = 1;
        [SerializeField] private UpgradeType type;
        [Tooltip("Meaning depends on Type, e.g. +0.15 = +15% engine speed, or +15 seconds for DeadlineExtender.")]
        [SerializeField] private float effectValue = 0.1f;

        public string Id => id;
        public string DisplayName => displayName;
        public string Description => description;
        public Sprite Icon => icon;
        public int UnlockCost => unlockCost;
        public int RequiredLevel => requiredLevel;
        public UpgradeType Type => type;
        public float EffectValue => effectValue;
    }
}
