using UnityEngine;

namespace DeliveryDisaster.Audio
{
    /// <summary>
    /// Central catalog of sound effects and music. Assign clips in the Inspector -
    /// AudioManager reads from a single instance of this asset. Add a new named
    /// slot here whenever a new system needs a distinct sound; arrays play a
    /// random clip from the set for natural variation (e.g. multiple crash sounds).
    /// </summary>
    [CreateAssetMenu(fileName = "SfxLibrary", menuName = "Delivery Disaster/SFX Library")]
    public class SfxLibrary : ScriptableObject
    {
        [Header("Delivery")]
        public AudioClip[] packagePickup;
        public AudioClip[] deliverySuccess;
        public AudioClip[] deliveryFail;
        public AudioClip[] timerLowWarning;

        [Header("Vehicle")]
        public AudioClip engineIdleLoop;
        public AudioClip[] collisionImpacts;
        public AudioClip[] breakdownStall;

        [Header("Disaster")]
        public AudioClip[] disasterWarningStingers;
        public AudioClip[] disasterStartStingers;
        public AudioClip[] explosionSounds;
        public AudioClip[] tornadoLoop;
        public AudioClip[] floodLoop;

        [Header("UI")]
        public AudioClip uiClick;
        public AudioClip uiConfirm;
        public AudioClip uiBack;
        public AudioClip moneyGain;
        public AudioClip levelUp;
        public AudioClip itemUnlocked;

        [Header("Music")]
        public AudioClip normalGameplayMusic;
        public AudioClip disasterMusic;
        public AudioClip mainMenuMusic;

        public AudioClip PickRandom(AudioClip[] clips)
        {
            if (clips == null || clips.Length == 0) return null;
            return clips[Random.Range(0, clips.Length)];
        }
    }
}
