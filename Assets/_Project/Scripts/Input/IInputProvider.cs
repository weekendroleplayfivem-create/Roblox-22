using UnityEngine;

namespace DeliveryDisaster.Input
{
    /// <summary>
    /// Thin abstraction over "where input comes from" so gameplay scripts (VehicleController,
    /// PlayerInteraction, PauseMenu) never call UnityEngine.Input directly. Ships with a
    /// legacy Input Manager implementation that works out of the box with keyboard and any
    /// XInput-style gamepad (using the default Horizontal/Vertical/Submit/Cancel axes Unity
    /// creates for every new project). Swap in a new-Input-System-backed implementation later
    /// (e.g. for full Steam Deck glyph support) by implementing this interface and changing
    /// what InputService.Current returns - nothing else in the game needs to change.
    /// </summary>
    public interface IInputProvider
    {
        float Steer { get; }          // -1..1
        float Throttle { get; }       // -1..1 (negative = reverse/brake)
        bool HandbrakePressed { get; }
        bool InteractPressed { get; }  // pickup/dropoff/context action, edge-triggered
        bool PausePressed { get; }     // edge-triggered
        bool HornPressed { get; }
    }
}
