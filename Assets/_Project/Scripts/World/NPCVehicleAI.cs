using System.Collections.Generic;
using UnityEngine;

namespace DeliveryDisaster.World
{
    /// <summary>
    /// Simple waypoint-following traffic AI. Deliberately lightweight (no
    /// NavMesh dependency) so it works on any road layout the moment waypoints
    /// are placed. Slows/stops for obstacles ahead via a forward raycast, so it
    /// naturally reacts to disaster-spawned hazards (road collapses, construction
    /// barriers, wrecked traffic) without any disaster needing to know about traffic.
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class NPCVehicleAI : MonoBehaviour
    {
        [SerializeField] private float moveSpeed = 8f;
        [SerializeField] private float turnSpeed = 4f;
        [SerializeField] private float waypointReachDistance = 2f;
        [SerializeField] private float obstacleCheckDistance = 6f;
        [SerializeField] private LayerMask obstacleLayers;

        private Waypoint currentTarget;
        private Rigidbody rb;
        private bool isExploded;

        public static readonly List<NPCVehicleAI> All = new List<NPCVehicleAI>();

        private void Awake() => rb = GetComponent<Rigidbody>();
        private void OnEnable() => All.Add(this);
        private void OnDisable() => All.Remove(this);

        public void SetStartWaypoint(Waypoint start) => currentTarget = start;

        private void FixedUpdate()
        {
            if (isExploded || currentTarget == null) return;

            Vector3 toTarget = currentTarget.transform.position - rb.position;
            toTarget.y = 0f;

            if (toTarget.magnitude < waypointReachDistance)
            {
                currentTarget = currentTarget.GetRandomNext();
                if (currentTarget == null) return;
                toTarget = currentTarget.transform.position - rb.position;
                toTarget.y = 0f;
            }

            Quaternion desiredRotation = Quaternion.LookRotation(toTarget.normalized, Vector3.up);
            rb.MoveRotation(Quaternion.Slerp(rb.rotation, desiredRotation, turnSpeed * Time.fixedDeltaTime));

            float speed = IsPathBlocked() ? 0f : moveSpeed;
            rb.MovePosition(rb.position + transform.forward * speed * Time.fixedDeltaTime);
        }

        private bool IsPathBlocked()
        {
            return Physics.Raycast(transform.position + Vector3.up, transform.forward, obstacleCheckDistance, obstacleLayers);
        }

        /// <summary>Called by VehicleExplosionDisaster - stops AI control and lets physics/ragdoll-style forces take over.</summary>
        public void Explode()
        {
            isExploded = true;
            if (rb != null)
            {
                rb.isKinematic = false;
                rb.AddExplosionForce(15f, transform.position, 5f);
            }
        }
    }
}
