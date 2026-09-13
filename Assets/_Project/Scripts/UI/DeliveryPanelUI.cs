using TMPro;
using UnityEngine;
using DeliveryDisaster.Core;
using DeliveryDisaster.Delivery;

namespace DeliveryDisaster.UI
{
    /// <summary>Shows the active job's pickup/destination and current phase (awaiting pickup vs in transit).</summary>
    public class DeliveryPanelUI : MonoBehaviour
    {
        [SerializeField] private GameObject panelRoot;
        [SerializeField] private TMP_Text titleText;
        [SerializeField] private TMP_Text targetLocationText;
        [SerializeField] private TMP_Text rewardText;

        private void OnEnable()
        {
            EventBus.Subscribe<DeliveryJobGeneratedEvent>(OnJobGenerated);
            EventBus.Subscribe<PackagePickedUpEvent>(OnPackagePickedUp);
            EventBus.Subscribe<DeliveryCompletedEvent>(OnJobEnded);
            EventBus.Subscribe<DeliveryFailedEvent>(OnJobEnded);
        }

        private void OnDisable()
        {
            EventBus.Unsubscribe<DeliveryJobGeneratedEvent>(OnJobGenerated);
            EventBus.Unsubscribe<PackagePickedUpEvent>(OnPackagePickedUp);
            EventBus.Unsubscribe<DeliveryCompletedEvent>(OnJobEnded);
            EventBus.Unsubscribe<DeliveryFailedEvent>(OnJobEnded);
        }

        private void OnJobGenerated(DeliveryJobGeneratedEvent evt)
        {
            SetActive(true);
            if (titleText != null) titleText.text = "Pick up package at:";
            if (targetLocationText != null) targetLocationText.text = evt.Job.Pickup.LocationName;
            if (rewardText != null) rewardText.text = $"${evt.Job.BaseReward}";
        }

        private void OnPackagePickedUp(PackagePickedUpEvent evt)
        {
            if (titleText != null) titleText.text = "Deliver to:";
            if (targetLocationText != null) targetLocationText.text = evt.Job.Dropoff.LocationName;
        }

        private void OnJobEnded(DeliveryCompletedEvent evt) => SetActive(false);
        private void OnJobEnded(DeliveryFailedEvent evt) => SetActive(false);

        private void SetActive(bool active)
        {
            if (panelRoot != null) panelRoot.SetActive(active);
        }
    }
}
