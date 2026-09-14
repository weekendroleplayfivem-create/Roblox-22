using TMPro;
using UnityEngine;
using DeliveryDisaster.Core;

namespace DeliveryDisaster.UI
{
    /// <summary>Small indicator showing the carried package's condition (pristine/damaged/destroyed).</summary>
    public class PackageStatusUI : MonoBehaviour
    {
        [SerializeField] private GameObject root;
        [SerializeField] private TMP_Text statusText;
        [SerializeField] private Color pristineColor = Color.white;
        [SerializeField] private Color damagedColor = new Color(1f, 0.6f, 0f);
        [SerializeField] private Color destroyedColor = Color.red;

        private void OnEnable()
        {
            EventBus.Subscribe<PackagePickedUpEvent>(OnPickedUp);
            EventBus.Subscribe<PackageConditionChangedEvent>(OnConditionChanged);
            EventBus.Subscribe<DeliveryCompletedEvent>(OnJobEnded);
            EventBus.Subscribe<DeliveryFailedEvent>(OnJobEnded);
        }

        private void OnDisable()
        {
            EventBus.Unsubscribe<PackagePickedUpEvent>(OnPickedUp);
            EventBus.Unsubscribe<PackageConditionChangedEvent>(OnConditionChanged);
            EventBus.Unsubscribe<DeliveryCompletedEvent>(OnJobEnded);
            EventBus.Unsubscribe<DeliveryFailedEvent>(OnJobEnded);
        }

        private void OnPickedUp(PackagePickedUpEvent evt) => SetVisible(true);
        private void OnJobEnded(DeliveryCompletedEvent evt) => SetVisible(false);
        private void OnJobEnded(DeliveryFailedEvent evt) => SetVisible(false);

        private void OnConditionChanged(PackageConditionChangedEvent evt)
        {
            if (statusText == null) return;

            switch (evt.Condition)
            {
                case PackageCondition.Pristine:
                    statusText.text = "Package: Pristine";
                    statusText.color = pristineColor;
                    break;
                case PackageCondition.Damaged:
                    statusText.text = "Package: Damaged";
                    statusText.color = damagedColor;
                    break;
                case PackageCondition.Destroyed:
                    statusText.text = "Package: Destroyed!";
                    statusText.color = destroyedColor;
                    break;
            }
        }

        private void SetVisible(bool visible)
        {
            if (root != null) root.SetActive(visible);
        }
    }
}
