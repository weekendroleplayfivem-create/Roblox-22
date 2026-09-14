using UnityEngine;
using DeliveryDisaster.Core;

namespace DeliveryDisaster.UI
{
    /// <summary>
    /// Top-level HUD container - just shows/hides itself based on GameState so
    /// individual widgets (timer, money, delivery panel, etc.) don't each need
    /// their own visibility logic. Attach to the root Canvas/panel holding all HUD elements.
    /// </summary>
    public class HUDController : MonoBehaviour
    {
        [SerializeField] private GameObject hudRoot;

        private void OnEnable() => EventBus.Subscribe<GameStateChangedEvent>(OnStateChanged);
        private void OnDisable() => EventBus.Unsubscribe<GameStateChangedEvent>(OnStateChanged);

        private void OnStateChanged(GameStateChangedEvent evt)
        {
            if (hudRoot != null)
            {
                hudRoot.SetActive(evt.State == GameState.Playing);
            }
        }
    }
}
