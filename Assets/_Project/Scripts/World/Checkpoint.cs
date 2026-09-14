using UnityEngine;
using DeliveryDisaster.Player;

namespace DeliveryDisaster.World
{
    /// <summary>
    /// Trigger volume the player drives through that records "last safe position".
    /// Used to recover a vehicle that gets stuck/flipped (flood, tornado, explosion
    /// knockback) via RespawnManager rather than ending the run over a physics mishap.
    /// </summary>
    public class Checkpoint : MonoBehaviour
    {
        public static Vector3 LastSafePosition { get; private set; }
        public static Quaternion LastSafeRotation { get; private set; } = Quaternion.identity;
        private static bool hasCheckpoint;

        private void OnTriggerEnter(Collider other)
        {
            if (other.attachedRigidbody != null && other.attachedRigidbody.TryGetComponent<PlayerReference>(out _))
            {
                LastSafePosition = transform.position;
                LastSafeRotation = transform.rotation;
                hasCheckpoint = true;
            }
        }

        /// <summary>Teleports the player's vehicle back to the last checkpoint (or its current position if none recorded yet), zeroing velocity.</summary>
        public static void RespawnPlayerIfStuck()
        {
            var player = PlayerReference.Active;
            if (player == null) return;

            Vector3 targetPos = hasCheckpoint ? LastSafePosition : player.transform.position + Vector3.up * 2f;
            Quaternion targetRot = hasCheckpoint ? LastSafeRotation : player.transform.rotation;

            player.Rigidbody.velocity = Vector3.zero;
            player.Rigidbody.angularVelocity = Vector3.zero;
            player.transform.SetPositionAndRotation(targetPos + Vector3.up * 0.5f, targetRot);
        }
    }
}
