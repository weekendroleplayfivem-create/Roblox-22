using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using DeliveryDisaster.Core;

namespace DeliveryDisaster.UI
{
    /// <summary>
    /// Toast/notification queue. Any system anywhere calls
    /// EventBus.Publish(new NotificationRequestedEvent(...)) and it shows up here -
    /// nothing needs a direct reference to this component.
    /// </summary>
    public class NotificationSystem : MonoBehaviour
    {
        [SerializeField] private RectTransform container;
        [SerializeField] private GameObject toastPrefab; // expects a TMP_Text somewhere in its hierarchy
        [SerializeField] private float toastLifetime = 3f;
        [SerializeField] private int maxVisibleToasts = 4;

        [Header("Colors")]
        [SerializeField] private Color infoColor = Color.white;
        [SerializeField] private Color successColor = new Color(0.3f, 1f, 0.4f);
        [SerializeField] private Color warningColor = new Color(1f, 0.7f, 0f);
        [SerializeField] private Color dangerColor = new Color(1f, 0.3f, 0.3f);

        private readonly Queue<GameObject> activeToasts = new Queue<GameObject>();

        private void OnEnable() => EventBus.Subscribe<NotificationRequestedEvent>(OnNotificationRequested);
        private void OnDisable() => EventBus.Unsubscribe<NotificationRequestedEvent>(OnNotificationRequested);

        private void OnNotificationRequested(NotificationRequestedEvent evt)
        {
            if (toastPrefab == null || container == null) return;

            while (activeToasts.Count >= maxVisibleToasts)
            {
                var oldest = activeToasts.Dequeue();
                if (oldest != null) Destroy(oldest);
            }

            var toast = Instantiate(toastPrefab, container);
            var text = toast.GetComponentInChildren<TMP_Text>();
            if (text != null)
            {
                text.text = evt.Message;
                text.color = evt.Type switch
                {
                    NotificationType.Success => successColor,
                    NotificationType.Warning => warningColor,
                    NotificationType.Danger => dangerColor,
                    _ => infoColor
                };
            }

            activeToasts.Enqueue(toast);
            StartCoroutine(RemoveAfterDelay(toast));
        }

        private IEnumerator RemoveAfterDelay(GameObject toast)
        {
            yield return new WaitForSeconds(toastLifetime);
            if (toast != null) Destroy(toast);
        }
    }
}
