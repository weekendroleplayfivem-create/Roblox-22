using UnityEngine;
using DeliveryDisaster.Core;

namespace DeliveryDisaster.Disasters
{
    /// <summary>
    /// Data-driven config for one disaster type. To add a brand new disaster to
    /// the game: write a class deriving from DisasterBase, make a prefab with it
    /// attached, create one of these assets pointing at that prefab
    /// (Assets > Create > Delivery Disaster > Disaster), and drop the asset into
    /// DisasterManager's pool. Nothing else needs to change.
    /// </summary>
    [CreateAssetMenu(fileName = "Disaster_", menuName = "Delivery Disaster/Disaster Definition")]
    public class DisasterDefinition : ScriptableObject
    {
        [SerializeField] private string disasterId = "disaster_id";
        [SerializeField] private string displayName = "Unnamed Disaster";
        [SerializeField, TextArea] private string description;
        [SerializeField] private Sprite warningIcon;
        [SerializeField] private DisasterSeverity severity = DisasterSeverity.Moderate;

        [Header("Prefab")]
        [Tooltip("Must have a component deriving from DisasterBase.")]
        [SerializeField] private GameObject disasterPrefab;

        [Header("Timing")]
        [SerializeField] private float warningDuration = 3f;
        [SerializeField] private float activeDuration = 10f;
        [SerializeField] private float cooldownSeconds = 25f;

        [Header("Spawning & Scheduling")]
        [Tooltip("Relative weight when randomly picking a disaster among eligible ones. Higher = more common.")]
        [SerializeField] private float spawnWeight = 1f;
        [Tooltip("Minimum DifficultyManager.CurrentDifficulty before this disaster can occur at all.")]
        [SerializeField] private float minDifficulty = 1f;
        [Tooltip("If set, DisasterManager looks for a DisasterSpawnPoint with this category instead of spawning near the player.")]
        [SerializeField] private string requiredSpawnCategory = "";

        public string DisasterId => disasterId;
        public string DisplayName => displayName;
        public string Description => description;
        public Sprite WarningIcon => warningIcon;
        public DisasterSeverity Severity => severity;
        public GameObject DisasterPrefab => disasterPrefab;
        public float WarningDuration => warningDuration;
        public float ActiveDuration => activeDuration;
        public float CooldownSeconds => cooldownSeconds;
        public float SpawnWeight => spawnWeight;
        public float MinDifficulty => minDifficulty;
        public string RequiredSpawnCategory => requiredSpawnCategory;
    }
}
