using UnityEngine;

namespace DeliveryDisaster.Input
{
    /// <summary>
    /// Default IInputProvider using Unity's classic Input Manager. Requires
    /// Project Settings > Player > Active Input Handling to include
    /// "Input Manager (Old)" (the project default). Works with keyboard/mouse
    /// and any controller mapped to the standard Horizontal/Vertical/Jump/
    /// Submit/Cancel axes Unity ships by default (Xbox/PlayStation/Steam
    /// Deck controllers all map through Steam Input or Windows XInput to these).
    /// </summary>
    public class LegacyInputProvider : IInputProvider
    {
        public float Steer => UnityEngine.Input.GetAxis("Horizontal");
        public float Throttle => UnityEngine.Input.GetAxis("Vertical");
        public bool HandbrakePressed => UnityEngine.Input.GetButton("Jump") || UnityEngine.Input.GetKey(KeyCode.Space);
        public bool InteractPressed => UnityEngine.Input.GetButtonDown("Submit") || UnityEngine.Input.GetKeyDown(KeyCode.E);
        public bool PausePressed => UnityEngine.Input.GetButtonDown("Cancel") || UnityEngine.Input.GetKeyDown(KeyCode.Escape);
        public bool HornPressed => UnityEngine.Input.GetKeyDown(KeyCode.H);
    }

    /// <summary>Static access point, mirroring SteamService's pattern for swappable implementations.</summary>
    public static class InputService
    {
        private static IInputProvider current;
        public static IInputProvider Current => current ??= new LegacyInputProvider();

        /// <summary>Allows SettingsMenu or platform-detection code to swap providers at runtime (e.g. controller vs KBM prompts).</summary>
        public static void SetProvider(IInputProvider provider) => current = provider;
    }
}
