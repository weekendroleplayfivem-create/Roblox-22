using TMPro;
using UnityEngine;
using UnityEngine.UI;
using DeliveryDisaster.Core;
using DeliveryDisaster.Economy;

namespace DeliveryDisaster.UI
{
    /// <summary>Displays money, level, and XP progress toward the next level.</summary>
    public class MoneyXpUI : MonoBehaviour
    {
        [SerializeField] private TMP_Text moneyText;
        [SerializeField] private TMP_Text levelText;
        [SerializeField] private Image xpFillBar;

        private void OnEnable()
        {
            EventBus.Subscribe<MoneyChangedEvent>(OnMoneyChanged);
            EventBus.Subscribe<XpChangedEvent>(OnXpChanged);
            EventBus.Subscribe<LevelUpEvent>(OnLevelUp);
        }

        private void OnDisable()
        {
            EventBus.Unsubscribe<MoneyChangedEvent>(OnMoneyChanged);
            EventBus.Unsubscribe<XpChangedEvent>(OnXpChanged);
            EventBus.Unsubscribe<LevelUpEvent>(OnLevelUp);
        }

        private void Start() => RefreshAll();

        private void RefreshAll()
        {
            if (EconomyManager.Instance != null && moneyText != null) moneyText.text = $"${EconomyManager.Instance.Money}";
            if (ProgressionManager.Instance != null)
            {
                if (levelText != null) levelText.text = $"Lv {ProgressionManager.Instance.Level}";
                if (xpFillBar != null) xpFillBar.fillAmount = ProgressionManager.Instance.ProgressToNextLevel();
            }
        }

        private void OnMoneyChanged(MoneyChangedEvent evt)
        {
            if (moneyText != null) moneyText.text = $"${evt.NewTotal}";
        }

        private void OnXpChanged(XpChangedEvent evt)
        {
            if (xpFillBar != null && ProgressionManager.Instance != null) xpFillBar.fillAmount = ProgressionManager.Instance.ProgressToNextLevel();
        }

        private void OnLevelUp(LevelUpEvent evt)
        {
            if (levelText != null) levelText.text = $"Lv {evt.NewLevel}";
        }
    }
}
