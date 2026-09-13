using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace DeliveryDisaster.World
{
    /// <summary>
    /// Optional marker for a location disasters can target that needs specific
    /// placement (a bridge, a road segment, a construction-ready lot) rather
    /// than a purely random point near the player. Tag with a category string
    /// that matches DisasterDefinition.RequiredSpawnCategory. Disasters with no
    /// required category ignore these entirely and spawn near the player instead.
    /// </summary>
    public class DisasterSpawnPoint : MonoBehaviour
    {
        [SerializeField] private string category = "Generic";

        public string Category => category;

        public static readonly List<DisasterSpawnPoint> All = new List<DisasterSpawnPoint>();

        private void OnEnable() => All.Add(this);
        private void OnDisable() => All.Remove(this);

        public static bool TryGetRandom(string forCategory, out Vector3 position)
        {
            var matches = All.Where(p => p.category == forCategory).ToList();
            if (matches.Count == 0)
            {
                position = default;
                return false;
            }

            position = matches[Random.Range(0, matches.Count)].transform.position;
            return true;
        }
    }
}
