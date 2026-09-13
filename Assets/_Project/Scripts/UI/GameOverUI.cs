using TMPro;
using UnityEngine;
using DeliveryDisaster.Core;

namespace DeliveryDisaster.UI
{
    /// <summary>Game over / run-summary screen shown when GameManager ends a run (too many failed deliveries).</summary>
    public class GameOverUI : MonoBehaviour
    {
        [SerializeField] private GameObject panelRoot;
        [SerializeField] private TMP_Text summaryText;

        private void OnEnable() => EventBus.Subscribe<GameStateChangedEvent>(OnStateChanged);
        private void OnDisable() => EventBus.Unsubscribe<GameStateChangedEvent>(OnStateChanged);

        private void OnStateChanged(GameStateChangedEvent evt)
        {
            bool isGameOver = evt.State == GameState.GameOver;
            if (panelRoot != null) panelRoot.SetActive(isGameOver);

            if (isGameOver && summaryText != null)
            {
                var gm = GameManager.Instance;
                summaryText.text =
                    $"Deliveries completed: {gm.DeliveriesCompletedThisRun}\n" +
                    $"Deliveries failed: {gm.DeliveriesFailedThisRun}\n" +
                    $"Disasters survived: {gm.DisastersSurvivedThisRun}";
            }
        }

        // --- Button hooks ---
        public void OnRetryClicked() => GameManager.Instance.StartNewRun();
        public void OnMainMenuClicked() => GameManager.Instance.QuitToMainMenu();
    }
}
