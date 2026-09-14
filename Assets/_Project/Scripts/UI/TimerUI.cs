using TMPro;
using UnityEngine;
using UnityEngine.UI;
using DeliveryDisaster.Core;

namespace DeliveryDisaster.UI
{
    /// <summary>Displays remaining delivery time as text and a fill bar; turns red and pulses when time is low.</summary>
    public class TimerUI : MonoBehaviour
    {
        [SerializeField] private TMP_Text timeText;
        [SerializeField] private Image fillBar;
        [SerializeField] private Color normalColor = Color.white;
        [SerializeField] private Color lowTimeColor = Color.red;
        [SerializeField] private float lowTimeThreshold01 = 0.25f;

        private void OnEnable() => EventBus.Subscribe<DeliveryTimerTickEvent>(OnTick);
        private void OnDisable() => EventBus.Unsubscribe<DeliveryTimerTickEvent>(OnTick);

        private void OnTick(DeliveryTimerTickEvent evt)
        {
            float fraction = evt.TotalSeconds <= 0f ? 0f : Mathf.Clamp01(evt.SecondsRemaining / evt.TotalSeconds);

            if (timeText != null)
            {
                int seconds = Mathf.CeilToInt(evt.SecondsRemaining);
                timeText.text = $"{seconds / 60:00}:{seconds % 60:00}";
                timeText.color = fraction <= lowTimeThreshold01 ? lowTimeColor : normalColor;
            }

            if (fillBar != null)
            {
                fillBar.fillAmount = fraction;
                fillBar.color = fraction <= lowTimeThreshold01 ? lowTimeColor : normalColor;
            }
        }
    }
}
