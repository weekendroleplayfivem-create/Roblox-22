using UnityEngine;
using DeliveryDisaster.Utils;
using DeliveryDisaster.SaveSystem;
using DeliveryDisaster.Core;

namespace DeliveryDisaster.Economy
{
    /// <summary>
    /// Single source of truth for the player's money. Wraps SaveManager.Data.Money
    /// so nothing else touches the save data directly; publishes MoneyChangedEvent
    /// for UI/audio to react to.
    /// </summary>
    public class EconomyManager : Singleton<EconomyManager>
    {
        public int Money => SaveManager.Instance.Data.Money;

        public void AddMoney(int amount)
        {
            if (amount == 0) return;
            var data = SaveManager.Instance.Data;
            data.Money = Mathf.Max(0, data.Money + amount);
            EventBus.Publish(new MoneyChangedEvent(data.Money, amount));
        }

        public bool TrySpend(int amount)
        {
            if (amount <= 0) return true;
            var data = SaveManager.Instance.Data;
            if (data.Money < amount) return false;

            data.Money -= amount;
            EventBus.Publish(new MoneyChangedEvent(data.Money, -amount));
            return true;
        }

        public bool CanAfford(int amount) => Money >= amount;
    }
}
