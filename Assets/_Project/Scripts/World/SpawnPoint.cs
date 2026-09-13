using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace DeliveryDisaster.World
{
    public enum SpawnPointType
    {
        PlayerStart,
        TrafficSpawn
    }

    /// <summary>
    /// Generic placeable spawn marker. Place several in the level and both
    /// VehicleSpawner (PlayerStart) and TrafficSpawner (TrafficSpawn) pick from
    /// them automatically - no manual wiring needed per spawn point.
    /// </summary>
    public class SpawnPoint : MonoBehaviour
    {
        [SerializeField] private SpawnPointType type = SpawnPointType.TrafficSpawn;

        public SpawnPointType Type => type;

        public static readonly List<SpawnPoint> All = new List<SpawnPoint>();

        private void OnEnable() => All.Add(this);
        private void OnDisable() => All.Remove(this);

        public static SpawnPoint GetRandom(SpawnPointType ofType)
        {
            var matches = All.Where(p => p.type == ofType).ToList();
            return matches.Count == 0 ? null : matches[Random.Range(0, matches.Count)];
        }

        private void OnDrawGizmos()
        {
            Gizmos.color = type == SpawnPointType.PlayerStart ? Color.green : Color.blue;
            Gizmos.DrawWireSphere(transform.position, 1f);
        }
    }
}
