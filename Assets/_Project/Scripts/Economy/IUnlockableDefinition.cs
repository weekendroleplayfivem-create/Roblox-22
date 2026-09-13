using UnityEngine;

namespace DeliveryDisaster.Economy
{
    /// <summary>
    /// Common contract for anything purchasable/unlockable (vehicles, upgrades,
    /// cosmetics). Letting UnlockManager work against this interface instead of
    /// three separate concrete types is what makes "add a new vehicle" or
    /// "add a new cosmetic" a data-only change - no manager code needs editing.
    /// </summary>
    public interface IUnlockableDefinition
    {
        string Id { get; }
        string DisplayName { get; }
        int UnlockCost { get; }
        int RequiredLevel { get; }
        Sprite Icon { get; }
    }
}
