using System.Collections.Generic;
using UnityEngine;
using DeliveryDisaster.Input;
using DeliveryDisaster.Core;

namespace DeliveryDisaster.Player
{
    /// <summary>
    /// Attach to the player vehicle root. Tracks every IInteractable currently
    /// overlapping the trigger volume on this object and lets the player
    /// activate the nearest one with the Interact button (pickup/dropoff/shop/etc).
    /// Requires a large-ish trigger Collider (kept separate from the vehicle's
    /// physical colliders) on this GameObject or a child.
    /// </summary>
    public class PlayerInteraction : MonoBehaviour
    {
        private readonly List<IInteractable> inRange = new List<IInteractable>();

        public IInteractable CurrentTarget { get; private set; }

        private void Update()
        {
            CurrentTarget = GetBestTarget();

            if (CurrentTarget != null && InputService.Current.InteractPressed)
            {
                CurrentTarget.Interact();
            }
        }

        private IInteractable GetBestTarget()
        {
            inRange.RemoveAll(i => i == null || !i.CanInteract);
            return inRange.Count > 0 ? inRange[0] : null;
        }

        private void OnTriggerEnter(Collider other)
        {
            if (other.TryGetComponent<IInteractable>(out var interactable) && !inRange.Contains(interactable))
            {
                inRange.Add(interactable);
            }
        }

        private void OnTriggerExit(Collider other)
        {
            if (other.TryGetComponent<IInteractable>(out var interactable))
            {
                inRange.Remove(interactable);
            }
        }
    }
}
