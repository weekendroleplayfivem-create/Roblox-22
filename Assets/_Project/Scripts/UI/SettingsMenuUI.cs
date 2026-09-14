using UnityEngine;
using UnityEngine.UI;
using TMPro;
using DeliveryDisaster.SaveSystem;
using DeliveryDisaster.Audio;

namespace DeliveryDisaster.UI
{
    /// <summary>Settings panel for audio volumes, graphics quality, and accessibility toggles. Reads/writes SaveManager.Data.Settings directly and applies changes live.</summary>
    public class SettingsMenuUI : MonoBehaviour
    {
        [SerializeField] private GameObject panelRoot;
        [SerializeField] private Slider masterVolumeSlider;
        [SerializeField] private Slider musicVolumeSlider;
        [SerializeField] private Slider sfxVolumeSlider;
        [SerializeField] private TMP_Dropdown qualityDropdown;
        [SerializeField] private Toggle invertYToggle;
        [SerializeField] private Toggle screenShakeToggle;
        [SerializeField] private Toggle subtitlesToggle;
        [SerializeField] private Toggle fullscreenToggle;

        private bool initializing;

        public void Open()
        {
            if (panelRoot != null) panelRoot.SetActive(true);
            LoadIntoUI();
        }

        public void Close()
        {
            if (panelRoot != null) panelRoot.SetActive(false);
        }

        private void LoadIntoUI()
        {
            initializing = true;
            var s = SaveManager.Instance.Data.Settings;

            if (masterVolumeSlider != null) masterVolumeSlider.value = s.MasterVolume;
            if (musicVolumeSlider != null) musicVolumeSlider.value = s.MusicVolume;
            if (sfxVolumeSlider != null) sfxVolumeSlider.value = s.SfxVolume;
            if (qualityDropdown != null) qualityDropdown.value = s.QualityLevel;
            if (invertYToggle != null) invertYToggle.isOn = s.InvertYLook;
            if (screenShakeToggle != null) screenShakeToggle.isOn = s.ScreenShakeEnabled;
            if (subtitlesToggle != null) subtitlesToggle.isOn = s.SubtitlesEnabled;
            if (fullscreenToggle != null) fullscreenToggle.isOn = s.Fullscreen;

            initializing = false;
        }

        // --- Wire these to the corresponding UI element's OnValueChanged in the Inspector ---

        public void OnMasterVolumeChanged(float value)
        {
            if (initializing) return;
            SaveManager.Instance.Data.Settings.MasterVolume = value;
            AudioManager.Instance?.ApplyVolumeSettings();
        }

        public void OnMusicVolumeChanged(float value)
        {
            if (initializing) return;
            SaveManager.Instance.Data.Settings.MusicVolume = value;
            AudioManager.Instance?.ApplyVolumeSettings();
        }

        public void OnSfxVolumeChanged(float value)
        {
            if (initializing) return;
            SaveManager.Instance.Data.Settings.SfxVolume = value;
            AudioManager.Instance?.ApplyVolumeSettings();
        }

        public void OnQualityChanged(int index)
        {
            if (initializing) return;
            SaveManager.Instance.Data.Settings.QualityLevel = index;
            QualitySettings.SetQualityLevel(index, applyExpensiveChanges: true);
        }

        public void OnInvertYChanged(bool value)
        {
            if (initializing) return;
            SaveManager.Instance.Data.Settings.InvertYLook = value;
        }

        public void OnScreenShakeChanged(bool value)
        {
            if (initializing) return;
            SaveManager.Instance.Data.Settings.ScreenShakeEnabled = value;
        }

        public void OnSubtitlesChanged(bool value)
        {
            if (initializing) return;
            SaveManager.Instance.Data.Settings.SubtitlesEnabled = value;
        }

        public void OnFullscreenChanged(bool value)
        {
            if (initializing) return;
            SaveManager.Instance.Data.Settings.Fullscreen = value;
            Screen.fullScreen = value;
        }

        public void OnBackClicked()
        {
            SaveManager.Instance.Save();
            Close();
        }
    }
}
