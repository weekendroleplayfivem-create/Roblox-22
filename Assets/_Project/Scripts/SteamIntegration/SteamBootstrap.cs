using UnityEngine;
using DeliveryDisaster.Utils;

namespace DeliveryDisaster.SteamIntegration
{
    /// <summary>
    /// Drives the Steamworks service lifecycle (init on boot, RunCallbacks per frame,
    /// shutdown on quit). Add one instance to the bootstrap scene alongside GameManager.
    /// Safe to include even without Steamworks.NET installed - it just drives the NoOp service.
    /// </summary>
    public class SteamBootstrap : Singleton<SteamBootstrap>
    {
        private void Start()
        {
            SteamService.Current.Initialize();
        }

        private void Update()
        {
            SteamService.Current.RunCallbacks();
        }

        protected override void OnApplicationQuit()
        {
            SteamService.Current.Shutdown();
            base.OnApplicationQuit();
        }
    }
}
