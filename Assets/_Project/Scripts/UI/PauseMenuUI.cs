using UnityEngine;
using DeliveryDisaster.Core;

namespace DeliveryDisaster.UI
{
    /// <summary>Pause menu panel - shows/hides itself with GameState and exposes button hooks for Resume/Settings/Quit.</summary>
    public class PauseMenuUI : MonoBehaviour
    {
        [SerializeField] private GameObject panelRoot;
        [SerializeField] private SettingsMenuUI settingsMenu;

        private void OnEnable() => EventBus.Subscribe<GameStateChangedEvent>(OnStateChanged);
        private void OnDisable() => EventBus.Unsubscribe<GameStateChangedEvent>(OnStateChanged);

        private void OnStateChanged(GameStateChangedEvent evt)
        {
            if (panelRoot != null) panelRoot.SetActive(evt.State == GameState.Paused);
        }

        // --- Button hooks (wire up in the Inspector) ---
        public void OnResumeClicked() => GameManager.Instance.TogglePause();
        public void OnSettingsClicked() => settingsMenu?.Open();
        public void OnQuitToMenuClicked() => GameManager.Instance.QuitToMainMenu();
        public void OnQuitApplicationClicked() => GameManager.Instance.QuitApplication();
    }
}
