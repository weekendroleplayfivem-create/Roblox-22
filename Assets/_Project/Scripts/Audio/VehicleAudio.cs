using UnityEngine;
using DeliveryDisaster.SaveSystem;
using DeliveryDisaster.Vehicles;

namespace DeliveryDisaster.Audio
{
    /// <summary>Drives a looping engine sound whose pitch follows engine load/speed. Attach to the vehicle prefab alongside VehicleController.</summary>
    [RequireComponent(typeof(VehicleController))]
    [RequireComponent(typeof(AudioSource))]
    public class VehicleAudio : MonoBehaviour
    {
        [SerializeField] private SfxLibrary library;
        [SerializeField] private float minPitch = 0.8f;
        [SerializeField] private float maxPitch = 2f;

        private VehicleController vehicle;
        private AudioSource source;

        private void Awake()
        {
            vehicle = GetComponent<VehicleController>();
            source = GetComponent<AudioSource>();
            source.loop = true;
            source.spatialBlend = 1f; // 3D - the engine should feel like it's coming from the vehicle
        }

        private void Start()
        {
            if (library != null && library.engineIdleLoop != null)
            {
                source.clip = library.engineIdleLoop;
                source.Play();
            }
        }

        private void Update()
        {
            if (!source.isPlaying) return;

            source.pitch = Mathf.Lerp(minPitch, maxPitch, vehicle.EngineLoad01);

            var s = SaveManager.Instance.Data.Settings;
            source.volume = s.MasterVolume * s.SfxVolume;
        }
    }
}
