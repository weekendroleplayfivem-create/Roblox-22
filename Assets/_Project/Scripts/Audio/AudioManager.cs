using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using DeliveryDisaster.Utils;
using DeliveryDisaster.Core;
using DeliveryDisaster.SaveSystem;
using DeliveryDisaster.Economy;
using DeliveryDisaster.Delivery;
using DeliveryDisaster.Disasters;
using DeliveryDisaster.Vehicles;

namespace DeliveryDisaster.Audio
{
    /// <summary>
    /// Central audio hub. Subscribes to EventBus so every gameplay system gets
    /// sound "for free" without knowing audio exists - dropping a new system's
    /// events into the switch statements here is the only wiring needed.
    /// Handles a simple two-track music crossfade (calm <-> disaster) and a
    /// small pooled set of 2D one-shot sources for SFX.
    /// </summary>
    public class AudioManager : Singleton<AudioManager>
    {
        [SerializeField] private SfxLibrary library;
        [SerializeField] private int sfxPoolSize = 8;
        [SerializeField] private float musicCrossfadeSeconds = 1.5f;

        private AudioSource musicSourceA;
        private AudioSource musicSourceB;
        private bool usingSourceA = true;
        private Coroutine crossfadeRoutine;

        private readonly List<AudioSource> sfxPool = new List<AudioSource>();
        private int nextSfxIndex;
        private int activeDisasterCount;

        protected override void Awake()
        {
            base.Awake();
            BuildAudioSources();
        }

        private void BuildAudioSources()
        {
            musicSourceA = CreateSource("MusicA", loop: true);
            musicSourceB = CreateSource("MusicB", loop: true);

            for (int i = 0; i < sfxPoolSize; i++)
            {
                sfxPool.Add(CreateSource($"Sfx_{i}", loop: false));
            }
        }

        private AudioSource CreateSource(string name, bool loop)
        {
            var go = new GameObject(name);
            go.transform.SetParent(transform);
            var source = go.AddComponent<AudioSource>();
            source.loop = loop;
            source.playOnAwake = false;
            source.spatialBlend = 0f; // 2D by default; disaster/impact one-shots use PlayClipAtPoint instead
            return source;
        }

        private void OnEnable()
        {
            EventBus.Subscribe<PackagePickedUpEvent>(OnPackagePickedUp);
            EventBus.Subscribe<DeliveryCompletedEvent>(OnDeliveryCompleted);
            EventBus.Subscribe<DeliveryFailedEvent>(OnDeliveryFailed);

            EventBus.Subscribe<DisasterTelegraphedEvent>(OnDisasterTelegraphed);
            EventBus.Subscribe<DisasterStartedEvent>(OnDisasterStarted);
            EventBus.Subscribe<DisasterEndedEvent>(OnDisasterEnded);

            EventBus.Subscribe<VehicleDamagedEvent>(OnVehicleDamaged);
            EventBus.Subscribe<VehicleBrokeDownEvent>(OnVehicleBrokeDown);

            EventBus.Subscribe<MoneyChangedEvent>(OnMoneyChanged);
            EventBus.Subscribe<LevelUpEvent>(OnLevelUp);
            EventBus.Subscribe<ItemUnlockedEvent>(OnItemUnlocked);

            EventBus.Subscribe<GameStateChangedEvent>(OnGameStateChanged);
        }

        private void OnDisable()
        {
            EventBus.Unsubscribe<PackagePickedUpEvent>(OnPackagePickedUp);
            EventBus.Unsubscribe<DeliveryCompletedEvent>(OnDeliveryCompleted);
            EventBus.Unsubscribe<DeliveryFailedEvent>(OnDeliveryFailed);

            EventBus.Unsubscribe<DisasterTelegraphedEvent>(OnDisasterTelegraphed);
            EventBus.Unsubscribe<DisasterStartedEvent>(OnDisasterStarted);
            EventBus.Unsubscribe<DisasterEndedEvent>(OnDisasterEnded);

            EventBus.Unsubscribe<VehicleDamagedEvent>(OnVehicleDamaged);
            EventBus.Unsubscribe<VehicleBrokeDownEvent>(OnVehicleBrokeDown);

            EventBus.Unsubscribe<MoneyChangedEvent>(OnMoneyChanged);
            EventBus.Unsubscribe<LevelUpEvent>(OnLevelUp);
            EventBus.Unsubscribe<ItemUnlockedEvent>(OnItemUnlocked);

            EventBus.Unsubscribe<GameStateChangedEvent>(OnGameStateChanged);
        }

        private void OnPackagePickedUp(PackagePickedUpEvent evt) => PlayOneShot(library?.PickRandom(library.packagePickup));
        private void OnDeliveryCompleted(DeliveryCompletedEvent evt) => PlayOneShot(library?.PickRandom(library.deliverySuccess));
        private void OnDeliveryFailed(DeliveryFailedEvent evt) => PlayOneShot(library?.PickRandom(library.deliveryFail));
        private void OnVehicleDamaged(VehicleDamagedEvent evt) => PlayOneShotAtPoint(library?.PickRandom(library.collisionImpacts), evt.Point);
        private void OnVehicleBrokeDown(VehicleBrokeDownEvent evt) => PlayOneShot(library?.PickRandom(library.breakdownStall));
        private void OnMoneyChanged(MoneyChangedEvent evt) { if (evt.Delta > 0) PlayOneShot(library?.moneyGain); }
        private void OnLevelUp(LevelUpEvent evt) => PlayOneShot(library?.levelUp);
        private void OnItemUnlocked(ItemUnlockedEvent evt) => PlayOneShot(library?.itemUnlocked);

        private void OnDisasterTelegraphed(DisasterTelegraphedEvent evt) => PlayOneShot(library?.PickRandom(library.disasterWarningStingers));

        private void OnDisasterStarted(DisasterStartedEvent evt)
        {
            PlayOneShot(library?.PickRandom(library.disasterStartStingers));
            activeDisasterCount++;
            if (activeDisasterCount == 1 && library?.disasterMusic != null) CrossfadeTo(library.disasterMusic);
        }

        private void OnDisasterEnded(DisasterEndedEvent evt)
        {
            activeDisasterCount = Mathf.Max(0, activeDisasterCount - 1);
            if (activeDisasterCount == 0 && library?.normalGameplayMusic != null) CrossfadeTo(library.normalGameplayMusic);
        }

        private void OnGameStateChanged(GameStateChangedEvent evt)
        {
            switch (evt.State)
            {
                case GameState.MainMenu:
                    activeDisasterCount = 0;
                    if (library?.mainMenuMusic != null) CrossfadeTo(library.mainMenuMusic);
                    break;
                case GameState.Playing:
                    if (library?.normalGameplayMusic != null) CrossfadeTo(library.normalGameplayMusic);
                    break;
            }
        }

        public void PlayOneShot(AudioClip clip)
        {
            if (clip == null) return;
            var source = sfxPool[nextSfxIndex];
            nextSfxIndex = (nextSfxIndex + 1) % sfxPool.Count;
            source.PlayOneShot(clip, EffectiveSfxVolume());
        }

        public void PlayOneShotAtPoint(AudioClip clip, Vector3 point)
        {
            if (clip == null) return;
            AudioSource.PlayClipAtPoint(clip, point, EffectiveSfxVolume());
        }

        /// <summary>Called by UI buttons directly (click/confirm/back) since those don't have dedicated EventBus events.</summary>
        public void PlayUiClick() => PlayOneShot(library?.uiClick);
        public void PlayUiConfirm() => PlayOneShot(library?.uiConfirm);
        public void PlayUiBack() => PlayOneShot(library?.uiBack);

        private void CrossfadeTo(AudioClip newClip)
        {
            if (crossfadeRoutine != null) StopCoroutine(crossfadeRoutine);
            crossfadeRoutine = StartCoroutine(CrossfadeRoutine(newClip));
        }

        private IEnumerator CrossfadeRoutine(AudioClip newClip)
        {
            var fadeIn = usingSourceA ? musicSourceB : musicSourceA;
            var fadeOut = usingSourceA ? musicSourceA : musicSourceB;
            usingSourceA = !usingSourceA;

            fadeIn.clip = newClip;
            fadeIn.volume = 0f;
            fadeIn.Play();

            float targetVolume = EffectiveMusicVolume();
            float t = 0f;
            while (t < musicCrossfadeSeconds)
            {
                t += Time.unscaledDeltaTime;
                float frac = Mathf.Clamp01(t / musicCrossfadeSeconds);
                fadeIn.volume = Mathf.Lerp(0f, targetVolume, frac);
                fadeOut.volume = Mathf.Lerp(targetVolume, 0f, frac);
                yield return null;
            }

            fadeOut.Stop();
        }

        /// <summary>Call after any settings volume slider changes.</summary>
        public void ApplyVolumeSettings()
        {
            float musicVol = EffectiveMusicVolume();
            if (musicSourceA.isPlaying) musicSourceA.volume = musicVol;
            if (musicSourceB.isPlaying) musicSourceB.volume = musicVol;
        }

        private float EffectiveMusicVolume()
        {
            var s = SaveManager.Instance.Data.Settings;
            return s.MasterVolume * s.MusicVolume;
        }

        private float EffectiveSfxVolume()
        {
            var s = SaveManager.Instance.Data.Settings;
            return s.MasterVolume * s.SfxVolume;
        }
    }
}
