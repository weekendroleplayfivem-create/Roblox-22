using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using DeliveryDisaster.Utils;
using DeliveryDisaster.Core;
using DeliveryDisaster.Economy;
using DeliveryDisaster.World;

namespace DeliveryDisaster.Disasters
{
    /// <summary>
    /// Schedules and runs disasters. Fully data-driven off the disasterPool list -
    /// adding a new DisasterDefinition asset to that list is the only step needed
    /// to bring a new disaster into rotation. Handles per-type cooldowns, weighted
    /// random selection scoped to eligible (difficulty-unlocked, off-cooldown)
    /// disasters, and difficulty-scaled spawn frequency.
    /// </summary>
    public class DisasterManager : Singleton<DisasterManager>
    {
        [SerializeField] private List<DisasterDefinition> disasterPool = new List<DisasterDefinition>();

        [Header("Spawn Pacing")]
        [SerializeField] private float baseMinInterval = 14f;
        [SerializeField] private float baseMaxInterval = 24f;
        [Tooltip("How much each point of difficulty shrinks the spawn interval, as a fraction.")]
        [SerializeField] private float intervalReductionPerDifficulty = 0.08f;
        [SerializeField] private float minIntervalFloor = 5f;

        [Header("Random Spawn (no required category)")]
        [SerializeField] private float randomSpawnRadiusMin = 15f;
        [SerializeField] private float randomSpawnRadiusMax = 40f;

        private readonly Dictionary<DisasterDefinition, float> cooldownExpiryTime = new Dictionary<DisasterDefinition, float>();
        private readonly List<GameObject> activeDisasterInstances = new List<GameObject>();

        private Coroutine schedulerRoutine;

        private void Start()
        {
            schedulerRoutine = StartCoroutine(SchedulerLoop());
        }

        private IEnumerator SchedulerLoop()
        {
            while (true)
            {
                yield return new WaitUntil(() => GameManager.Instance.CurrentState == GameState.Playing);

                float difficulty = DifficultyManager.Instance != null ? DifficultyManager.Instance.CurrentDifficulty : 1f;
                float interval = Mathf.Max(minIntervalFloor,
                    Random.Range(baseMinInterval, baseMaxInterval) * (1f - intervalReductionPerDifficulty * (difficulty - 1f)));

                yield return new WaitForSeconds(interval);

                if (GameManager.Instance.CurrentState != GameState.Playing) continue;

                TrySpawnRandomDisaster(difficulty);
            }
        }

        private void TrySpawnRandomDisaster(float difficulty)
        {
            var eligible = disasterPool.Where(d => d != null && d.DisasterPrefab != null
                && difficulty >= d.MinDifficulty
                && (!cooldownExpiryTime.TryGetValue(d, out var expiry) || Time.time >= expiry))
                .ToList();

            if (eligible.Count == 0) return;

            var chosen = WeightedPick(eligible);
            Vector3 spawnPoint = ResolveSpawnLocation(chosen);
            StartCoroutine(RunDisaster(chosen, spawnPoint, difficulty));
        }

        private static DisasterDefinition WeightedPick(List<DisasterDefinition> options)
        {
            float totalWeight = options.Sum(o => Mathf.Max(0.01f, o.SpawnWeight));
            float roll = Random.Range(0f, totalWeight);
            float cumulative = 0f;

            foreach (var option in options)
            {
                cumulative += Mathf.Max(0.01f, option.SpawnWeight);
                if (roll <= cumulative) return option;
            }

            return options[options.Count - 1];
        }

        private Vector3 ResolveSpawnLocation(DisasterDefinition definition)
        {
            if (!string.IsNullOrEmpty(definition.RequiredSpawnCategory) &&
                DisasterSpawnPoint.TryGetRandom(definition.RequiredSpawnCategory, out var taggedPosition))
            {
                return taggedPosition;
            }

            Transform playerTransform = Player.PlayerReference.Active != null ? Player.PlayerReference.Active.transform : null;
            Vector3 origin = playerTransform != null ? playerTransform.position : Vector3.zero;

            Vector2 randomCircle = Random.insideUnitCircle.normalized * Random.Range(randomSpawnRadiusMin, randomSpawnRadiusMax);
            Vector3 offset = new Vector3(randomCircle.x, 0f, randomCircle.y);

            Vector3 candidate = origin + offset;

            if (Physics.Raycast(candidate + Vector3.up * 100f, Vector3.down, out var hit, 500f))
            {
                candidate.y = hit.point.y;
            }

            return candidate;
        }

        private IEnumerator RunDisaster(DisasterDefinition definition, Vector3 location, float difficulty)
        {
            cooldownExpiryTime[definition] = Time.time + definition.CooldownSeconds;

            var instance = Instantiate(definition.DisasterPrefab, location, Quaternion.identity);
            activeDisasterInstances.Add(instance);

            if (!instance.TryGetComponent<IDisaster>(out var disaster))
            {
                Debug.LogError($"[DisasterManager] {definition.DisasterPrefab.name} has no IDisaster component - destroying.");
                Destroy(instance);
                yield break;
            }

            disaster.Setup(definition, location, difficulty);

            disaster.Telegraph();
            EventBus.Publish(new DisasterTelegraphedEvent(definition, location, definition.WarningDuration));
            yield return new WaitForSeconds(definition.WarningDuration);

            disaster.Activate();
            EventBus.Publish(new DisasterStartedEvent(definition));
            yield return new WaitForSeconds(definition.ActiveDuration);

            disaster.Cleanup();
            EventBus.Publish(new DisasterEndedEvent(definition));
            GameManager.Instance.ReportDisasterSurvived();

            activeDisasterInstances.Remove(instance);
        }

        /// <summary>Force-ends every active disaster immediately - used when returning to main menu / ending a run.</summary>
        public void ClearAllActiveDisasters()
        {
            foreach (var instance in activeDisasterInstances.ToList())
            {
                if (instance == null) continue;
                if (instance.TryGetComponent<IDisaster>(out var disaster)) disaster.Cleanup();
                else Destroy(instance);
            }
            activeDisasterInstances.Clear();
        }
    }
}
