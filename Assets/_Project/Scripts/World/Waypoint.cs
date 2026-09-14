using System.Collections.Generic;
using UnityEngine;

namespace DeliveryDisaster.World
{
    /// <summary>
    /// Single node in the road network's waypoint graph. NPC traffic follows
    /// chains of these rather than needing a baked NavMesh - place waypoints
    /// along your roads in the Editor and link each one's Next list to
    /// continue the route (supports branches/intersections via multiple Next entries).
    /// </summary>
    public class Waypoint : MonoBehaviour
    {
        [SerializeField] private List<Waypoint> next = new List<Waypoint>();

        public IReadOnlyList<Waypoint> Next => next;

        public Waypoint GetRandomNext()
        {
            if (next.Count == 0) return null;
            return next[Random.Range(0, next.Count)];
        }

        private void OnDrawGizmos()
        {
            Gizmos.color = Color.cyan;
            Gizmos.DrawSphere(transform.position, 0.4f);

            Gizmos.color = Color.yellow;
            foreach (var n in next)
            {
                if (n != null) Gizmos.DrawLine(transform.position, n.transform.position);
            }
        }
    }
}
