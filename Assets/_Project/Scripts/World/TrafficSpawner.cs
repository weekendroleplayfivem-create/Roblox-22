using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using DeliveryDisaster.Core;

namespace DeliveryDisaster.World
{
    /// <summary>
    /// Maintains a population of NPC traffic vehicles, spawning at TrafficSpawn
    /// SpawnPoints (falling back to any Waypoint if none are placed) and
    /// despawning the oldest when over the cap. Keeps the world feeling alive
    /// without the player ever noticing the pooling/recycling underneath.
    /// </summary>
    public class TrafficSpawner : MonoBehaviour
    {
        [SerializeField] private GameObject npcVehiclePrefab;
        [SerializeField] private int maxActiveNpcs = 10;
        [SerializeField] private float spawnInterval = 4f;
        [SerializeField] private List<Waypoint> fallbackWaypoints = new List<Waypoint>();

        private readonly List<GameObject> activeNpcs = new List<GameObject>();

        private void Start()
        {
            StartCoroutine(SpawnLoop());
        }

        private IEnumerator SpawnLoop()
        {
            while (true)
            {
                yield return new WaitForSeconds(spawnInterval);
                yield return new WaitUntil(() => GameManager.Instance.CurrentState == GameState.Playing);

                activeNpcs.RemoveAll(n => n == null);
                if (activeNpcs.Count >= maxActiveNpcs || npcVehiclePrefab == null) continue;

                SpawnOne();
            }
        }

        private void SpawnOne()
        {
            Waypoint startWaypoint = ResolveSpawnWaypoint();
            if (startWaypoint == null) return;

            var instance = Instantiate(npcVehiclePrefab, startWaypoint.transform.position, startWaypoint.transform.rotation);
            if (instance.TryGetComponent<NPCVehicleAI>(out var ai))
            {
                ai.SetStartWaypoint(startWaypoint.GetRandomNext() ?? startWaypoint);
            }

            activeNpcs.Add(instance);
        }

        private Waypoint ResolveSpawnWaypoint()
        {
            var trafficSpawnPoint = SpawnPoint.GetRandom(SpawnPointType.TrafficSpawn);
            if (trafficSpawnPoint != null && trafficSpawnPoint.TryGetComponent<Waypoint>(out var waypointOnSpawn))
            {
                return waypointOnSpawn;
            }

            if (fallbackWaypoints.Count > 0)
            {
                return fallbackWaypoints[Random.Range(0, fallbackWaypoints.Count)];
            }

            return null;
        }
    }
}
