using System.Collections.Generic;
using UnityEngine;
using DeliveryDisaster.Player;

namespace DeliveryDisaster.Delivery
{
    /// <summary>
    /// Marks a point in the world that can serve as a delivery pickup and/or
    /// dropoff. Drop this component on any GameObject with a trigger Collider
    /// to make it a valid delivery location - DeliveryManager picks randomly
    /// among all registered locations, so adding a new delivery location to
    /// the level is just "place a prefab with this script", no manager edits.
    /// </summary>
    public class DeliveryLocation : MonoBehaviour, IInteractable
    {
        [SerializeField] private string locationName = "Delivery Point";
        [SerializeField] private bool canBePickup = true;
        [SerializeField] private bool canBeDropoff = true;
        [SerializeField] private Transform packageAnchor;

        public static readonly List<DeliveryLocation> All = new List<DeliveryLocation>();

        public string LocationName => locationName;
        public bool CanBePickup => canBePickup;
        public bool CanBeDropoff => canBeDropoff;
        public Transform PackageAnchor => packageAnchor != null ? packageAnchor : transform;

        /// <summary>Set by DeliveryManager when this location is the pickup or dropoff for the active job.</summary>
        public DeliveryJob AssignedJob { get; set; }
        public bool IsAssignedAsPickup { get; set; }

        public string InteractionPrompt =>
            AssignedJob == null ? string.Empty :
            IsAssignedAsPickup ? $"Pick up package for {locationName}" : $"Deliver package to {locationName}";

        public bool CanInteract => AssignedJob != null;

        private void OnEnable() => All.Add(this);
        private void OnDisable() => All.Remove(this);

        public void Interact()
        {
            if (AssignedJob == null || DeliveryManager.Instance == null) return;

            if (IsAssignedAsPickup)
            {
                DeliveryManager.Instance.TryPickupPackage(this);
            }
            else
            {
                DeliveryManager.Instance.TryDeliverPackage(this);
            }
        }
    }
}
