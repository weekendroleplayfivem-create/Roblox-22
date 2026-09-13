using System.Collections;
using TMPro;
using UnityEngine;
using UnityEngine.UI;
using DeliveryDisaster.Core;
using DeliveryDisaster.Disasters;

namespace DeliveryDisaster.UI
{
    /// <summary>Big warning banner shown during a disaster's telegraph window ("TORNADO INCOMING") so players get a fair chance to react.</summary>
    public class DisasterWarningUI : MonoBehaviour
    {
        [SerializeField] private GameObject bannerRoot;
        [SerializeField] private TMP_Text warningText;
        [SerializeField] private Image warningIcon;
        [SerializeField] private CanvasGroup canvasGroup;
        [SerializeField] private float flashSpeed = 6f;

        private Coroutine flashRoutine;

        private void OnEnable()
        {
            EventBus.Subscribe<DisasterTelegraphedEvent>(OnTelegraphed);
            EventBus.Subscribe<DisasterStartedEvent>(OnStarted);
        }

        private void OnDisable()
        {
            EventBus.Unsubscribe<DisasterTelegraphedEvent>(OnTelegraphed);
            EventBus.Unsubscribe<DisasterStartedEvent>(OnStarted);
        }

        private void OnTelegraphed(DisasterTelegraphedEvent evt)
        {
            if (bannerRoot != null) bannerRoot.SetActive(true);
            if (warningText != null) warningText.text = $"{evt.Definition.DisplayName.ToUpperInvariant()} INCOMING!";
            if (warningIcon != null) warningIcon.sprite = evt.Definition.WarningIcon;

            if (flashRoutine != null) StopCoroutine(flashRoutine);
            if (canvasGroup != null) flashRoutine = StartCoroutine(Flash(evt.WarningDuration));
        }

        private void OnStarted(DisasterStartedEvent evt)
        {
            if (flashRoutine != null) StopCoroutine(flashRoutine);
            if (bannerRoot != null) bannerRoot.SetActive(false);
        }

        private IEnumerator Flash(float duration)
        {
            float elapsed = 0f;
            while (elapsed < duration)
            {
                canvasGroup.alpha = 0.5f + 0.5f * Mathf.Sin(Time.time * flashSpeed);
                elapsed += Time.deltaTime;
                yield return null;
            }
            canvasGroup.alpha = 1f;
        }
    }
}
