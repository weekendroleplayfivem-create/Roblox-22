using UnityEngine;
using DeliveryDisaster.Core;
using DeliveryDisaster.Input;

namespace DeliveryDisaster.UI
{
    /// <summary>Watches for the pause button and toggles GameManager's pause state. Place one instance in the gameplay scene.</summary>
    public class PauseInputListener : MonoBehaviour
    {
        private void Update()
        {
            if (InputService.Current.PausePressed &&
                (GameManager.Instance.CurrentState == GameState.Playing || GameManager.Instance.CurrentState == GameState.Paused))
            {
                GameManager.Instance.TogglePause();
            }
        }
    }
}
