using UnityEngine;
using DeliveryDisaster.Core;

namespace DeliveryDisaster.UI
{
    /// <summary>Main menu panel - the game's entry point. Shows/hides with GameState.MainMenu.</summary>
    public class MainMenuUI : MonoBehaviour
    {
        [SerializeField] private GameObject panelRoot;
        [SerializeField] private SettingsMenuUI settingsMenu;

        private void OnEnable() => EventBus.Subscribe<GameStateChangedEvent>(OnStateChanged);
        private void OnDisable() => EventBus.Unsubscribe<GameStateChangedEvent>(OnStateChanged);

        private void OnStateChanged(GameStateChangedEvent evt)
        {
            if (panelRoot != null) panelRoot.SetActive(evt.State == GameState.MainMenu);
        }

        public void OnPlayClicked() => GameManager.Instance.StartNewRun();
        public void OnSettingsClicked() => settingsMenu?.Open();
        public void OnQuitClicked() => GameManager.Instance.QuitApplication();
    }
}
