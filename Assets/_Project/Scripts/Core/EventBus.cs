using System;
using System.Collections.Generic;

namespace DeliveryDisaster.Core
{
    /// <summary>
    /// Lightweight static publish/subscribe hub. Keeps gameplay systems decoupled -
    /// e.g. AudioManager and UI never need a direct reference to DeliveryManager or
    /// DisasterManager, they just listen for the events they care about.
    ///
    /// Usage:
    ///   EventBus.Subscribe&lt;DeliveryCompletedEvent&gt;(OnDeliveryCompleted);
    ///   EventBus.Publish(new DeliveryCompletedEvent(job));
    /// </summary>
    public static class EventBus
    {
        private static readonly Dictionary<Type, Delegate> handlers = new Dictionary<Type, Delegate>();

        public static void Subscribe<T>(Action<T> handler)
        {
            var type = typeof(T);
            if (handlers.TryGetValue(type, out var existing))
            {
                handlers[type] = Delegate.Combine(existing, handler);
            }
            else
            {
                handlers[type] = handler;
            }
        }

        public static void Unsubscribe<T>(Action<T> handler)
        {
            var type = typeof(T);
            if (!handlers.TryGetValue(type, out var existing)) return;

            var result = Delegate.Remove(existing, handler);
            if (result == null)
            {
                handlers.Remove(type);
            }
            else
            {
                handlers[type] = result;
            }
        }

        public static void Publish<T>(T evt)
        {
            var type = typeof(T);
            if (handlers.TryGetValue(type, out var existing) && existing is Action<T> action)
            {
                action.Invoke(evt);
            }
        }

        /// <summary>Call on session/domain reload boundaries (e.g. returning to main menu) to avoid stale listeners.</summary>
        public static void ClearAll() => handlers.Clear();
    }

    // ---- Delivery events ----
    public readonly struct DeliveryJobGeneratedEvent { public readonly Delivery.DeliveryJob Job; public DeliveryJobGeneratedEvent(Delivery.DeliveryJob job) => Job = job; }
    public readonly struct PackagePickedUpEvent { public readonly Delivery.DeliveryJob Job; public PackagePickedUpEvent(Delivery.DeliveryJob job) => Job = job; }
    public readonly struct DeliveryCompletedEvent { public readonly Delivery.DeliveryJob Job; public readonly int Payout; public readonly int XpGained; public DeliveryCompletedEvent(Delivery.DeliveryJob job, int payout, int xp) { Job = job; Payout = payout; XpGained = xp; } }
    public readonly struct DeliveryFailedEvent { public readonly Delivery.DeliveryJob Job; public readonly string Reason; public DeliveryFailedEvent(Delivery.DeliveryJob job, string reason) { Job = job; Reason = reason; } }
    public readonly struct DeliveryTimerTickEvent { public readonly float SecondsRemaining; public readonly float TotalSeconds; public DeliveryTimerTickEvent(float remaining, float total) { SecondsRemaining = remaining; TotalSeconds = total; } }
    public readonly struct PackageConditionChangedEvent { public readonly PackageCondition Condition; public PackageConditionChangedEvent(PackageCondition condition) => Condition = condition; }

    // ---- Economy / progression events ----
    public readonly struct MoneyChangedEvent { public readonly int NewTotal; public readonly int Delta; public MoneyChangedEvent(int newTotal, int delta) { NewTotal = newTotal; Delta = delta; } }
    public readonly struct XpChangedEvent { public readonly int NewTotal; public readonly int Delta; public XpChangedEvent(int newTotal, int delta) { NewTotal = newTotal; Delta = delta; } }
    public readonly struct LevelUpEvent { public readonly int NewLevel; public LevelUpEvent(int newLevel) => NewLevel = newLevel; }
    public readonly struct ItemUnlockedEvent { public readonly string ItemId; public readonly string DisplayName; public ItemUnlockedEvent(string itemId, string displayName) { ItemId = itemId; DisplayName = displayName; } }

    // ---- Disaster events ----
    public readonly struct DisasterTelegraphedEvent { public readonly Disasters.DisasterDefinition Definition; public readonly UnityEngine.Vector3 Location; public readonly float WarningDuration; public DisasterTelegraphedEvent(Disasters.DisasterDefinition def, UnityEngine.Vector3 location, float warning) { Definition = def; Location = location; WarningDuration = warning; } }
    public readonly struct DisasterStartedEvent { public readonly Disasters.DisasterDefinition Definition; public DisasterStartedEvent(Disasters.DisasterDefinition def) => Definition = def; }
    public readonly struct DisasterEndedEvent { public readonly Disasters.DisasterDefinition Definition; public DisasterEndedEvent(Disasters.DisasterDefinition def) => Definition = def; }

    // ---- UI / meta events ----
    public readonly struct NotificationRequestedEvent { public readonly string Message; public readonly NotificationType Type; public NotificationRequestedEvent(string message, NotificationType type) { Message = message; Type = type; } }
    public readonly struct GameStateChangedEvent { public readonly GameState State; public GameStateChangedEvent(GameState state) => State = state; }
    public readonly struct VehicleDamagedEvent { public readonly float DamagePercent; public readonly UnityEngine.Vector3 Point; public VehicleDamagedEvent(float damagePercent, UnityEngine.Vector3 point) { DamagePercent = damagePercent; Point = point; } }
    public readonly struct VehicleBrokeDownEvent { }
}
